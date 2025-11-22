class Agents::BaseAgent
  attr_reader :agent, :current_version, :enabled_models, :input

  delegate :agent_name, to: :class

  def initialize
    @agent = Agent.with_name(agent_name).active.first
    raise ArgumentError, "Agent '#{agent_name}' not found or inactive" unless @agent

    @current_version = @agent.current_agent_version
    raise ArgumentError, "Agent '#{agent_name}' has no current version" unless @current_version

    @enabled_models = @current_version.enabled_llm_models
    raise ArgumentError, "Agent '#{agent_name}' has no enabled models" unless @enabled_models.any?
  end

  def name
    @agent.name
  end

  def normalized_name
    @agent.normalized_name
  end

  def version
    @current_version.version
  end

  def primary_model
    # @enabled_models.find_by_external_id!("microsoft/phi-3.5-mini-128k-instruct")
    @enabled_models.first
  end

  def hyperparams
    @hyperparams ||= @current_version.hyperparams
  end

  def call(input)
    @input = input

    validator = input_validator
    unless validator.valid?
      raise ArgumentError, "Input validation failed: #{validator.errors.full_messages.join(', ')}"
    end
  end

  protected

  def extract_json_from_response(content)
    content = content.strip

    # Handle JSON wrapped in markdown code blocks
    if content.start_with?("```json") && content.end_with?("```")
      content = content[7..-4].strip  # Remove ```json and ```
    elsif content.start_with?("```") && content.end_with?("```")
      content = content[3..-4].strip   # Remove ``` and ```
    end

    content
  end

  def parse_and_validate_json_response(response)
    content = extract_json_from_response(response.content)
    data = JSON.parse(content)
    validate_output(data)
    data
  rescue JSON::ParserError => e
    raise ArgumentError, "Invalid JSON response from LLM: #{e.message}"
  end

  def validate_output(data)
    output_validator = build_output_validator(data)
    unless output_validator.valid?
      raise ArgumentError, "Output validation failed: #{output_validator.errors.full_messages.join(', ')}"
    end
    data
  end

  def build_output_validator(data)
    "Agents::Outputs::#{self.class.name.demodulize}Output".constantize.new(data)
  rescue NameError
    nil
  end

  def input_validator
    @input_validator ||= "Agents::Inputs::#{self.class.name.demodulize}Input".constantize.new(@input)
  end

  def self.agent_name(name = nil)
    return @agent_name if @agent_name

    if name
      @agent_name = name.to_s
    else
      @agent_name || self.name.demodulize.underscore
    end
  end

  def schema
    raise NotImplementedError
  end

  def chat(model = primary_model)
    params = hyperparams
    chat = RubyLLM.chat(model: model.external_id)

    chat.with_instructions(@current_version.instructions)
    chat.with_temperature(hyperparams.delete(:temperature)) if params[:temperature]
    chat.with_params(**params) if params.any?
    chat
  end
end
