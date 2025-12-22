class Agent::Output::QueryPlannerOutput < Agent::Output::BaseOutput
  VALID_MODELS = %w[an_stakeholders an_bodies an_body_types an_terms an_stakeholder_addresses].freeze
  VALID_OPERATORS = %w[= != > < >= <= IN LIKE ILIKE BETWEEN].freeze
  VALID_JOIN_TYPES = %w[INNER LEFT RIGHT].freeze
  VALID_AGGREGATION_FUNCTIONS = %w[COUNT SUM AVG MAX MIN].freeze
  VALID_LOOKUP_MODES = %w[first all].freeze

  attribute :steps, array: true, default: []

  validates :steps, presence: { message: "Query plan must contain 'steps'" }
  validate :validate_steps_structure

  def initialize(attributes = {})
    super(attributes)
  end

  private

  def validate_steps_structure
    return unless steps

    unless steps.is_a?(Array) && steps.any?
      errors.add(:steps, "must contain at least one step")
      return
    end

    steps.each_with_index do |step, index|
      validate_step(step, index)
    end
  end

  def validate_step(step, index)
    step_prefix = "Step #{index + 1}"

    unless step.is_a?(Hash)
      errors.add(:steps, "#{step_prefix} must be a hash")
      return
    end

    validate_required_fields(step, step_prefix)
    validate_target_model(step, step_prefix)
    validate_numeric_fields(step, step_prefix)
    validate_filter_logic(step, step_prefix)
    validate_nested_structures(step, step_prefix)
  end

  def validate_required_fields(step, step_prefix)
    unless step["id"]
      errors.add(:steps, "#{step_prefix}: id is required")
    end

    unless step["target_model"]
      errors.add(:steps, "#{step_prefix}: target_model is required")
    end
  end

  def validate_target_model(step, step_prefix)
    return unless step["target_model"]

    unless VALID_MODELS.include?(step["target_model"])
      errors.add(:steps, "#{step_prefix}: target_model must be one of #{VALID_MODELS.join(', ')}")
    end
  end

  def validate_numeric_fields(step, step_prefix)
    validate_limit(step, step_prefix)
    validate_offset(step, step_prefix)
  end

  def validate_limit(step, step_prefix)
    return unless step["limit"]

    unless step["limit"].is_a?(Integer) && step["limit"] > 0 && step["limit"] <= 50
      errors.add(:steps, "#{step_prefix}: limit must be an integer between 1 and 50")
    end
  end

  def validate_offset(step, step_prefix)
    return unless step["offset"]

    unless step["offset"].is_a?(Integer) && step["offset"] >= 0
      errors.add(:steps, "#{step_prefix}: offset must be a non-negative integer")
    end
  end

  def validate_filter_logic(step, step_prefix)
    return unless step["filter_logic"]

    unless %w[AND OR].include?(step["filter_logic"])
      errors.add(:steps, "#{step_prefix}: filter_logic must be 'AND' or 'OR'")
    end
  end

  def validate_nested_structures(step, step_prefix)
    validate_filters(step["filters"], step_prefix) if step["filters"]
    validate_joins(step["joins"], step_prefix) if step["joins"]
    validate_aggregation(step["aggregation"], step_prefix) if step["aggregation"]
  end

  def validate_filters(filters, step_prefix)
    unless filters.is_a?(Array)
      errors.add(:steps, "#{step_prefix}: filters must be an array")
      return
    end

    filters.each_with_index do |filter, filter_index|
      filter_prefix = "#{step_prefix}, Filter #{filter_index + 1}"

      unless filter.is_a?(Hash)
        errors.add(:steps, "#{filter_prefix}: must be a hash")
        next
      end

      unless filter["field"] && filter["op"] && filter.key?("value")
        errors.add(:steps, "#{filter_prefix}: must have field, op, and value")
        next
      end

      unless VALID_OPERATORS.include?(filter["op"])
        errors.add(:steps, "#{filter_prefix}: op must be one of #{VALID_OPERATORS.join(', ')}")
      end

      # Validate filter value - can be simple value or lookup object
      validate_filter_value(filter["value"], filter_prefix)
    end
  end

  def validate_joins(joins, step_prefix)
    unless joins.is_a?(Array)
      errors.add(:steps, "#{step_prefix}: joins must be an array")
      return
    end

    joins.each_with_index do |join, join_index|
      join_prefix = "#{step_prefix}, Join #{join_index + 1}"

      unless join.is_a?(Hash)
        errors.add(:steps, "#{join_prefix}: must be a hash")
        next
      end

      unless join["model"] && join["on"]
        errors.add(:steps, "#{join_prefix}: must have model and on")
        next
      end

      unless VALID_MODELS.include?(join["model"])
        errors.add(:steps, "#{join_prefix}: model must be one of #{VALID_MODELS.join(', ')}")
      end

      if join["type"] && !VALID_JOIN_TYPES.include?(join["type"])
        errors.add(:steps, "#{join_prefix}: type must be one of #{VALID_JOIN_TYPES.join(', ')}")
      end
    end
  end

  def validate_filter_value(value, filter_prefix)
    # If value is a hash, it should be a lookup reference
    if value.is_a?(Hash)
      unless value["step_id"] && value["field"]
        errors.add(:steps, "#{filter_prefix}: lookup value must have step_id and field")
        return
      end

      if value["mode"] && !VALID_LOOKUP_MODES.include?(value["mode"])
        errors.add(:steps, "#{filter_prefix}: lookup mode must be 'first' or 'all'")
      end
    end
    # For non-hash values (string, number, boolean, array), we don't need specific validation
    # as they are handled by the application logic
  end

  def validate_aggregation(aggregation, step_prefix)
    unless aggregation.is_a?(Hash)
      errors.add(:steps, "#{step_prefix}: aggregation must be a hash")
      return
    end

    unless aggregation["function"] && aggregation["field"]
      errors.add(:steps, "#{step_prefix}: aggregation must have function and field")
      return
    end

    unless VALID_AGGREGATION_FUNCTIONS.include?(aggregation["function"])
      errors.add(:steps, "#{step_prefix}: aggregation function must be one of #{VALID_AGGREGATION_FUNCTIONS.join(', ')}")
    end
  end
end
