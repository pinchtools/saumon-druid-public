class Agents::YamlValidatorService
  include ActiveModel::Validations

  attr_reader :raw_yaml

  validate :validate_structure

  def initialize(raw_yaml)
    @raw_yaml = raw_yaml
  end

  def valid_params
    raise ArgumentError, "Invalid YAML structure: #{errors.full_messages.join(', ')}" unless valid?

    permitted_params
  end

  private

  def validate_structure
    return add_error("YAML cannot be nil") if raw_yaml.nil?
    return add_error("YAML must be a hash") unless raw_yaml.is_a?(Hash)

    validate_agent_presence
    validate_agent_structure if raw_yaml["agent"]
  end

  def validate_agent_presence
    add_error("Missing 'agent' key") unless raw_yaml.key?("agent")
  end

  def validate_agent_structure
    agent_data = raw_yaml["agent"]
    return add_error("Agent must be a hash") unless agent_data.is_a?(Hash)

    validate_required_fields(agent_data)
    validate_fields_format(agent_data)
  end

  def validate_required_fields(agent_data)
    required_fields = %w[name description role directives models]

    required_fields.each do |field|
      add_error("Missing required field: agent.#{field}") if agent_data[field].blank?
    end
  end

  def validate_fields_format(agent_data)
    %w[name description role directives].each do |field|
      validate_string(field, agent_data[field])
    end

    validate_array("models", agent_data["models"])
    validate_json("context_format", agent_data["context_format"]) if agent_data["context_format"]
    validate_hash("hyperparams", agent_data["hyperparams"]) if agent_data["hyperparams"]
  end

  def validate_string(k, v)
    add_error("#{k} must be a string") unless v.is_a?(String) && !v.empty?
  end

  def validate_json(k, v)
    return add_error("#{k} must be a string") unless v.is_a?(String)

    begin
      add_error("Invalid #{k}: must be a valid JSON array") unless JSON.parse(v).is_a?(Array)
    rescue JSON::ParserError => e
      add_error("Invalid #{k}: #{e.message}")
    end
  end

  def validate_hash(k, v)
    return add_error("#{k} must be a hash") unless v.is_a?(Hash)

    true
  end

  def validate_array(k, v)
    return add_error("#{k} must be an array") unless v.is_a?(Array)
    return add_error("#{k} array cannot be empty") if v.empty?

    true
  end

  def permitted_params
    agent_data = raw_yaml["agent"]

    {
      "name" => agent_data["name"],
      "description" => agent_data["description"],
      "role" => agent_data["role"],
      "directives" => agent_data["directives"],
      "context_format" => agent_data["context_format"],
      "hyperparams" => agent_data["hyperparams"],
      "models" => agent_data["models"]
    }.compact
  end

  def add_error(message)
    errors.add(:base, message)
  end
end
