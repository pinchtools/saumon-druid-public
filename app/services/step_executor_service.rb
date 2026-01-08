# frozen_string_literal: true

class StepExecutorService
  class StepExecutionError < StandardError
    attr_reader :error_type, :details

    def initialize(message, error_type:, details: nil)
      super(message)
      @error_type = error_type
      @details = details
    end

    def french_message
      QueryExecution::FrenchErrors.for(error_type, **details.to_h.symbolize_keys)
    end
  end

  MODEL_MAPPING = {
    "stakeholder" => An::Stakeholder,
    "terms" => An::Term,
    "body" => An::Body
  }.freeze

  VALID_SCOPES = %w[active past main].freeze

  NO_PARAM_ACTIONS = %w[with_members].freeze

  DATE_OP_METHODS = {
    "EQ" => :date_eq,
    "BEFORE" => :date_before,
    "AFTER" => :date_after,
    "BETWEEN" => :date_between
  }.freeze

  # Whitelist of valid foreign keys for dependency filtering
  FOREIGN_KEY_MAPPING = {
    "stakeholder" => :an_stakeholder_id,
    "terms" => :an_term_id,
    "body" => :an_body_id
  }.freeze

  def initialize(step, context)
    @step = step.with_indifferent_access
    @context = context
  end

  def execute
    return skip_result if any_dependency_failed?

    model_class = resolve_model
    query = build_query(model_class)
    data = execute_query(query)

    QueryExecution::StepResult.success(step_id: step_id, data: data, target_model: @step["target_model"])
  rescue StepExecutionError => e
    QueryExecution::StepResult.failed(
      step_id: step_id,
      error_message_fr: e.french_message,
      error_details: { type: e.error_type, details: e.details }
    )
  rescue StandardError => e
    Rails.logger.error("StepExecutorService error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    QueryExecution::StepResult.failed(
      step_id: step_id,
      error_message_fr: QueryExecution::FrenchErrors.for(:unknown_error),
      error_details: { exception: e.class.name, message: e.message }
    )
  end

  private

  attr_reader :step, :context

  def step_id
    @step["id"]
  end

  def any_dependency_failed?
    return false unless @step["depends_on"]&.any?

    @step["depends_on"].any? do |dep_id|
      result = @context.get_result(dep_id)
      result.nil? || result.failed? || result.skipped?
    end
  end

  def skip_result
    QueryExecution::StepResult.skipped(step_id: step_id)
  end

  def resolve_model
    model_name = @step["target_model"]
    model_class = MODEL_MAPPING[model_name]

    unless model_class
      raise StepExecutionError.new(
        "Unknown model: #{model_name}",
        error_type: :model_not_found,
        details: { model: model_name }
      )
    end

    model_class
  end

  def build_query(model_class)
    query = model_class.all

    query = apply_action(query, model_class)
    query = apply_scope(query)
    query = apply_date_filter(query)
    query = apply_dependency_filter(query, model_class)
    query = apply_ordering(query)
    query = apply_distinct(query)
    query = apply_pagination(query)

    query
  end

  def apply_action(query, _model_class)
    action = @step["action"]
    return query unless action

    params = @step["parameters"] || []
    model_name = @step["target_model"]

    validate_action_exists!(query, action, model_name)

    if NO_PARAM_ACTIONS.include?(action)
      query.public_send(action)
    else
      validate_params!(params, 1, action)
      query.public_send(action, params[0])
    end
  end

  def validate_action_exists!(query, action, model_name)
    return if query.respond_to?(action)

    raise_invalid_action(action, model_name)
  end

  def apply_scope(query)
    scope = @step["scope"]
    return query unless scope && VALID_SCOPES.include?(scope)
    return query unless query.respond_to?(scope)

    query.public_send(scope)
  end

  def apply_date_filter(query)
    date_op = @step["date_op"]
    date_args = @step["date_args"]
    return query unless date_op && date_args&.any?

    method_name = DATE_OP_METHODS[date_op]
    return query unless method_name && query.respond_to?(method_name)

    query.public_send(method_name, *date_args)
  rescue ArgumentError => e
    raise StepExecutionError.new(
      "Invalid date format: #{e.message}",
      error_type: :invalid_date,
      details: { date_args: date_args }
    )
  end

  def apply_dependency_filter(query, _model_class)
    depends_on = @step["depends_on"]
    return query unless depends_on&.any?

    depends_on.each do |dep_id|
      dep_result = @context.get_result(dep_id)
      next unless dep_result&.success? && dep_result.data.present?

      query = filter_by_dependency(query, dep_result)
    end

    query
  end

  def filter_by_dependency(query, dep_result)
    dep_ids = extract_ids(dep_result.data)
    return query if dep_ids.empty?

    dep_model = dep_result.target_model
    current_model = @step["target_model"]

    if dep_model == current_model
      query.where(id: dep_ids)
    else
      foreign_key = FOREIGN_KEY_MAPPING[dep_model]
      return query unless foreign_key

      query.where(foreign_key => dep_ids)
    end
  end

  def extract_ids(data)
    return [] unless data.is_a?(Array)

    data.filter_map { |item| item.is_a?(Hash) ? item["id"] : nil }
  end

  def apply_ordering(query)
    order = @step["order"]
    return query unless order.present?

    query.order(Arel.sql(sanitize_order(order)))
  end

  def apply_distinct(query)
    return query unless @step["distinct"]

    query.distinct
  end

  def apply_pagination(query)
    limit = @step["limit"]
    offset = @step["offset"]

    query = query.limit(limit) if limit
    query = query.offset(offset) if offset

    query
  end

  def execute_query(query)
    if @step["count"]
      [ { "count" => query.count } ]
    else
      query.to_a.map { |record| serialize_record(record) }
    end
  rescue ActiveRecord::StatementInvalid => e
    raise StepExecutionError.new(
      "Database error: #{e.message}",
      error_type: :database_error,
      details: { query: query.to_sql }
    )
  end

  def serialize_record(record)
    record.attributes
      .except("uid", "created_at", "updated_at")
      .transform_keys(&:to_s)
  end

  def validate_params!(params, expected_count, action)
    return if params.is_a?(Array) && params.size >= expected_count

    raise StepExecutionError.new(
      "Action '#{action}' requires #{expected_count} parameter(s)",
      error_type: :invalid_parameters,
      details: { action: action, expected: expected_count, got: params&.size || 0 }
    )
  end

  def raise_invalid_action(action, model)
    raise StepExecutionError.new(
      "Invalid action '#{action}' for model '#{model}'",
      error_type: :invalid_action,
      details: { action: action, model: model }
    )
  end

  def sanitize_order(order_string)
    allowed_pattern = /\A[\w\s,.]+(ASC|DESC)?\z/i
    return "id ASC" unless order_string.match?(allowed_pattern)

    order_string
  end
end
