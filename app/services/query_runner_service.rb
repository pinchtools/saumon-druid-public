class QueryRunnerService
  class QueryError < StandardError; end
  class ModelNotFoundError < QueryError; end
  class LookupError < QueryError; end
  class ScopeError < QueryError; end

  MODEL_MAPPING = {
    "an_stakeholders" => "An::Stakeholder",
    "an_bodies" => "An::Body",
    "an_body_types" => "An::BodyType",
    "an_terms" => "An::Term",
    "an_stakeholder_addresses" => "An::StakeholderAddress",
    "an_countries" => "An::Country",
    "an_substitutes" => "An::Substitute",
    "an_bodies_countries" => "An::BodyCountry"
  }.freeze

  # Allowlist of scopes per model for security
  # Only these scopes can be called by the query planner
  ALLOWED_SCOPES = {
    "An::Stakeholder" => %w[lexical_search semantic_search hybrid_search],
    "An::Term" => %w[main active past by_hierarchy by_body_type date_eq date_before date_after date_between],
    "An::Body" => %w[active by_type date_eq date_before date_after date_between],
    "An::BodyType" => [],
    "An::StakeholderAddress" => [],
    "An::Country" => [],
    "An::Substitute" => []
  }.freeze

  VALID_DATE_OPS = %w[EQ BEFORE AFTER BETWEEN].freeze

  def initialize(query_plan)
    @query_plan = query_plan
    @step_results = {}
  end

  def execute
    validate_query_plan!

    @query_plan["steps"].each do |step|
      @step_results[step["id"]] = execute_step(step) if step["id"]
    end

    build_context
  end

  private

  def validate_query_plan!
    raise QueryError, "Query plan must be a Hash" unless @query_plan.is_a?(Hash)
    raise QueryError, "Query plan must contain 'steps'" unless @query_plan.key?("steps")

    steps = @query_plan["steps"]
    raise QueryError, "Query plan must contain at least one step" unless steps.is_a?(Array) && steps.any?
  end

  def execute_step(step)
    model_class = get_model_class(step["target_model"])
    query = build_base_query(model_class, step)

    query = apply_scopes(query, model_class, step["scopes"]) if step["scopes"]&.any?
    query = apply_date_filter(query, step) if step["date_op"]
    query = apply_joins(query, step["joins"]) if step["joins"]&.any?
    query = apply_filters(query, step) if step["filters"]&.any?
    query = apply_aggregation(query, step["aggregation"]) if step["aggregation"]
    query = apply_ordering(query, step["order"]) if step["order"]
    query = apply_distinct(query) if step["distinct"]
    query = apply_pagination(query, step["limit"], step["offset"])

    execute_query(query, step)
  end

  def get_model_class(model_name)
    class_name = MODEL_MAPPING[model_name]
    raise ModelNotFoundError, "Unknown model: #{model_name}" unless class_name

    class_name.constantize
  end

  def build_base_query(model_class, step)
    query = model_class

    if step["fields"]&.any?
      # Validate fields exist on the model
      invalid_fields = step["fields"] - model_class.column_names
      raise QueryError, "Invalid fields for #{step["target_model"]}: #{invalid_fields.join(', ')}" if invalid_fields.any?

      query = query.select(step["fields"])
    end

    query
  end

  def apply_scopes(query, model_class, scopes)
    allowed = ALLOWED_SCOPES[model_class.name] || []

    scopes.each do |scope_spec|
      scope_name = scope_spec["name"]

      unless allowed.include?(scope_name)
        raise ScopeError, "Scope '#{scope_name}' is not allowed for #{model_class.name}"
      end

      unless model_class.respond_to?(scope_name)
        raise ScopeError, "Scope '#{scope_name}' does not exist on #{model_class.name}"
      end

      args = scope_spec["args"] || []
      query = query.public_send(scope_name, *args)
    end

    query
  end

  def apply_date_filter(query, step)
    date_op = step["date_op"]
    date_args = step["date_args"]

    return query unless date_op && date_args

    case date_op
    when "EQ"
      query.date_eq(date_args[0])
    when "BEFORE"
      query.date_before(date_args[0])
    when "AFTER"
      query.date_after(date_args[0])
    when "BETWEEN"
      query.date_between(date_args[0], date_args[1])
    else
      raise QueryError, "Unknown date_op: #{date_op}. Valid values: #{VALID_DATE_OPS.join(', ')}"
    end
  end

  def apply_joins(query, joins)
    joins.each do |join_spec|
      # Convert association name to symbol for ActiveRecord
      association = join_spec["on"].to_sym

      case (join_spec["type"] || "LEFT").upcase
      when "INNER"
        query = query.joins(association)
      when "LEFT"
        query = query.left_joins(association)
      when "RIGHT"
        # ActiveRecord doesn't have native right join, use joins
        query = query.joins(association)
      end
    end

    query
  end

  def apply_filters(query, step)
    conditions = build_conditions(step["filters"], step)

    if step["filter_logic"] == "OR"
      query.where(conditions.join(" OR "))
    else
      conditions.each { |condition| query = query.where(condition) }
      query
    end
  end

  def build_conditions(filters, step)
    filters.map do |filter|
      value = resolve_filter_value(filter["value"], step)
      build_condition(filter["field"], filter["op"], value)
    end
  end

  def resolve_filter_value(value, step)
    if value.is_a?(Hash) && value["step_id"]
      lookup_value(value, step)
    else
      value
    end
  end

  def lookup_value(lookup_ref, current_step)
    unless @step_results.key?(lookup_ref["step_id"])
      raise LookupError, "Referenced step '#{lookup_ref["step_id"]}' not found or not executed yet"
    end

    results = @step_results[lookup_ref["step_id"]]
    return nil if results.empty?

    case lookup_ref["mode"] || "first"
    when "first"
      results.first[lookup_ref["field"]]
    when "all"
      results.map { |record| record[lookup_ref["field"]] }.compact
    else
      raise LookupError, "Invalid lookup mode: #{lookup_ref["mode"]}"
    end
  end

  def build_condition(field, operator, value)
    case operator
    when "="
      { field => value }
    when "!="
      [ "#{field} != ?", value ]
    when ">", "<", ">=", "<="
      [ "#{field} #{operator} ?", value ]
    when "IN"
      { field => value }
    when "LIKE"
      [ "#{field} LIKE ?", value ]
    when "ILIKE"
      [ "#{field} ILIKE ?", value ]
    when "BETWEEN"
      [ "#{field} BETWEEN ? AND ?", value[0], value[1] ]
    else
      raise QueryError, "Unsupported operator: #{operator}"
    end
  end

  def apply_aggregation(query, aggregation)
    case aggregation["function"].upcase
    when "COUNT"
      query = query.group(aggregation["group_by"]) if aggregation["group_by"]&.any?
      query.count(aggregation["field"])
    when "SUM"
      query = query.group(aggregation["group_by"]) if aggregation["group_by"]&.any?
      query.sum(aggregation["field"])
    when "AVG"
      query = query.group(aggregation["group_by"]) if aggregation["group_by"]&.any?
      query.average(aggregation["field"])
    when "MAX"
      query = query.group(aggregation["group_by"]) if aggregation["group_by"]&.any?
      query.maximum(aggregation["field"])
    when "MIN"
      query = query.group(aggregation["group_by"]) if aggregation["group_by"]&.any?
      query.minimum(aggregation["field"])
    else
      raise QueryError, "Unsupported aggregation function: #{aggregation["function"]}"
    end
  end

  def apply_ordering(query, order_spec)
    query.order(order_spec)
  end

  def apply_distinct(query)
    query.distinct
  end

  def apply_pagination(query, limit, offset)
    query = query.limit(limit) if limit && limit > 0
    query = query.offset(offset) if offset && offset > 0
    query
  end

  def execute_query(query, step)
    results = query.to_a

    # Convert to hash representation for easier processing
    results.map do |record|
      if record.respond_to?(:attributes)
        record.attributes
      else
        record # For aggregation results
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    raise QueryError, "Database error in step '#{step["id"]}': #{e.message}"
  end

  def build_context
    context = {}

    @query_plan["steps"].each_with_index do |step, index|
      label = step["context_label"] || step["id"] || "step_#{index}"

      if step["id"] && @step_results.key?(step["id"])
        context[label] = @step_results[step["id"]]
      elsif !step["id"]
        # For steps without ID, execute them directly for the context
        context[label] = execute_step(step)
      end
    end

    context
  end
end
