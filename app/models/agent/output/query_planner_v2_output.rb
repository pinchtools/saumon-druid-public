class Agent::Output::QueryPlannerV2Output < Agent::Output::BaseOutput
  VALID_MODELS = %w[stakeholder terms body].freeze
  VALID_SCOPES = %w[active past at_date main].freeze
  VALID_QUANTIFIERS = %w[one many].freeze
  VALID_DATE_OPS = %w[EQ BEFORE AFTER BETWEEN].freeze
  DATE_FILTERABLE_MODELS = %w[terms body].freeze

  VALID_ACTIONS = {
    "stakeholder" => %w[search search_by_gender search_by_occupation search_by_department search_by_political_group search_by_political_orientation],
    "terms" => %w[get_all by_body_type by_capacity],
    "body" => %w[search by_type get_members by_political_orientation]
  }.freeze

  attribute :confidence, :integer
  attribute :confidence_rationale, :string
  attribute :steps, array: true, default: []

  validates :steps, presence: { message: "Query plan must contain 'steps'" }
  validates :confidence, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
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

    step_ids = []
    steps.each_with_index do |step, index|
      validate_step(step, index, step_ids)
      step_ids << step["id"] if step["id"]
    end
  end

  def validate_step(step, index, existing_step_ids)
    step_prefix = "Step #{index + 1}"

    unless step.is_a?(Hash)
      errors.add(:steps, "#{step_prefix} must be a hash")
      return
    end

    validate_required_fields(step, step_prefix)
    validate_target_model(step, step_prefix)
    validate_action(step, step_prefix)
    validate_scope(step, step_prefix)
    validate_quantifier(step, step_prefix)
    validate_numeric_fields(step, step_prefix)
    validate_depends_on(step, step_prefix, existing_step_ids)
    validate_date_filter(step, step_prefix)
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

  def validate_action(step, step_prefix)
    return unless step["action"] && step["target_model"]

    valid_actions_for_model = VALID_ACTIONS[step["target_model"]]
    return unless valid_actions_for_model

    unless valid_actions_for_model.include?(step["action"])
      errors.add(:steps, "#{step_prefix}: action '#{step["action"]}' is not valid for model '#{step["target_model"]}'. Valid actions: #{valid_actions_for_model.join(', ')}")
    end
  end

  def validate_scope(step, step_prefix)
    return unless step["scope"]

    unless VALID_SCOPES.include?(step["scope"])
      errors.add(:steps, "#{step_prefix}: scope must be one of #{VALID_SCOPES.join(', ')}")
    end
  end

  def validate_quantifier(step, step_prefix)
    return unless step["quantifier"]

    unless VALID_QUANTIFIERS.include?(step["quantifier"])
      errors.add(:steps, "#{step_prefix}: quantifier must be one of #{VALID_QUANTIFIERS.join(', ')}")
    end
  end

  def validate_numeric_fields(step, step_prefix)
    validate_limit(step, step_prefix)
    validate_offset(step, step_prefix)
  end

  def validate_limit(step, step_prefix)
    return unless step["limit"]

    unless step["limit"].is_a?(Integer) && step["limit"] > 0 && step["limit"] <= 100
      errors.add(:steps, "#{step_prefix}: limit must be an integer between 1 and 100")
    end
  end

  def validate_offset(step, step_prefix)
    return unless step["offset"]

    unless step["offset"].is_a?(Integer) && step["offset"] >= 0
      errors.add(:steps, "#{step_prefix}: offset must be a non-negative integer")
    end
  end

  def validate_depends_on(step, step_prefix, existing_step_ids)
    return unless step["depends_on"]

    unless step["depends_on"].is_a?(Array)
      errors.add(:steps, "#{step_prefix}: depends_on must be an array")
      return
    end

    step["depends_on"].each do |dep_id|
      unless existing_step_ids.include?(dep_id)
        errors.add(:steps, "#{step_prefix}: depends_on references unknown step '#{dep_id}'")
      end
    end
  end

  def validate_date_filter(step, step_prefix)
    date_op = step["date_op"]
    date_args = step["date_args"]

    # If neither is present, nothing to validate
    return unless date_op || date_args

    # If one is present, both must be present
    if date_op && !date_args
      errors.add(:steps, "#{step_prefix}: date_args is required when date_op is specified")
      return
    end

    if date_args && !date_op
      errors.add(:steps, "#{step_prefix}: date_op is required when date_args is specified")
      return
    end

    # Validate date_op value
    unless VALID_DATE_OPS.include?(date_op)
      errors.add(:steps, "#{step_prefix}: date_op must be one of #{VALID_DATE_OPS.join(', ')}")
      return
    end

    # Validate date_args is an array
    unless date_args.is_a?(Array)
      errors.add(:steps, "#{step_prefix}: date_args must be an array")
      return
    end

    # Validate date_args length based on operation
    expected_args = date_op == "BETWEEN" ? 2 : 1
    unless date_args.length == expected_args
      errors.add(:steps, "#{step_prefix}: date_op '#{date_op}' requires #{expected_args} date_args, got #{date_args.length}")
      return
    end

    # Validate that model supports date filtering
    target_model = step["target_model"]
    if target_model && !DATE_FILTERABLE_MODELS.include?(target_model)
      errors.add(:steps, "#{step_prefix}: date filtering is not supported for model '#{target_model}'. Supported models: #{DATE_FILTERABLE_MODELS.join(', ')}")
      return
    end

    # Validate date_args values are parseable
    validate_date_args(date_args, step_prefix)
  end

  def validate_date_args(date_args, step_prefix)
    date_args.each_with_index do |arg, index|
      next if arg.nil?

      begin
        # Try to parse as date period (year, year-month, or full date)
        case arg.to_s
        when /\A\d{4}\z/, /\A\d{4}-\d{1,2}\z/
          # Valid year or year-month format
          next
        else
          Date.parse(arg.to_s)
        end
      rescue ArgumentError
        errors.add(:steps, "#{step_prefix}: date_args[#{index}] '#{arg}' is not a valid date format")
      end
    end
  end
end
