class An::BaseCorrectionDetector
  attr_reader :record, :session_id

  def initialize(record, session_id:)
    @record = record
    @session_id = session_id
  end

  def detect_all
    self.class::CORRECTIONS_CONFIG.filter_map do |correction_config|
      apply_correction(correction_config) if matches_conditions?(correction_config["conditions"])
    end
  end

  def detect_one(name)
    correction_config = self.class::CORRECTIONS_CONFIG.find { |correction_config| correction_config["name"] == name }

    return apply_correction(correction_config) if correction_config && matches_conditions?(correction_config["conditions"])

    nil
  end

  def correction(field, before:, after:, reason:)
    {
      correction_changes: {
        field => {
          "before" => before,
          "after" => after
        }
      },
      reason: reason,
      correction_type: "automatic",
      session_id: session_id
    }
  end

  protected

  def load_corrections_config(filename)
    YAML.safe_load_file(Rails.root.join("config", "corrections", filename))
  end

  def matches_conditions?(conditions)
    return true if conditions.nil?

    check_conditions(conditions["record"], record)
  end

  def apply_correction(config)
    correction_data = config["correction"]

    correction(
      correction_data["field"],
      before: correction_data["before"],
      after: correction_data["after"],
      reason: correction_data["reason"]
    )
  end

  private

  def check_conditions(condition_hash, target)
    return true if condition_hash.nil?

    condition_hash.all? do |key, expected_value|
      actual_value = resolve_value(target, key)
      values_match?(actual_value, expected_value)
    end
  end

  def resolve_value(object, path)
    path.to_s.split(".").reduce(object) do |obj, attr|
      obj&.public_send(attr)
    end
  end

  def values_match?(actual_value, expected_value)
    case expected_value
    when "blank"
      actual_value.blank?
    when nil, "null"
      actual_value.nil?
    else
      actual_value == expected_value
    end
  end
end
