class Agent::BaseAgent
  include ActiveSupport::Callbacks
  include JsonRepairable
  include Agent::RubyLlmRescuable

  class OutputValidationError < StandardError
    attr_reader :data

    def initialize(message, data: nil)
      super(message)
      @data = data
    end
  end

  define_callbacks :llm_call

  attr_reader :agent, :current_version, :enabled_models, :input, :last_response

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

  def parse_and_validate_json_response(response, retry_count: 0)
    data = repair_json(response.content)
    validate_output(data)
    data
  rescue JsonRepairable::RepairError => e
    raise ArgumentError, "Invalid JSON response from LLM: #{e.message}"
  rescue OutputValidationError => e
    # If this is the first attempt, try to handle it as a tool response
    if retry_count == 0
      handle_tool_response_retry(e.data, response)
    else
      raise ArgumentError, e.message
    end
  end

  def handle_tool_response_retry(data, original_response)
    # Override this method in subclasses to customize retry behavior
    # Default implementation re-raises the validation error
    raise OutputValidationError.new(
      "Output validation failed: model returned unexpected format",
      data: data
    )
  end

  def validate_output(data)
    output_validator = build_output_validator(data)
    unless output_validator.valid?
      raise OutputValidationError.new(
        "Output validation failed: #{output_validator.errors.full_messages.join(', ')}",
        data: data
      )
    end
    data
  end

  def build_output_validator(data)
    "Agent::Output::#{self.class.name.demodulize}Output".constantize.new(data)
  rescue NameError
    nil
  end

  def input_validator
    @input_validator ||= "Agent::Input::#{self.class.name.demodulize}Input".constantize.new(@input)
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
    with_llm_error_handling do
      params = hyperparams.dup
      @current_chat = RubyLLM.chat(model: model.external_id)
      @current_model = model

      @current_chat.with_instructions(@current_version.instructions)
      @current_chat.with_temperature(params.delete(:temperature)) if params[:temperature]
      @current_chat.with_params(**params) if params.any?

      @current_chat.with_tools(*tools)

      @current_chat
    end
  end

  # Wrapper for chat.ask that tracks events before/after the LLM call
  def ask(question)
    with_llm_error_handling do
      run_callbacks :llm_call do
        @last_response = @current_chat.ask(question)
      end
      @last_response
    end
  end

  set_callback :llm_call, :before, :track_llm_request
  set_callback :llm_call, :after, :track_llm_response

  private

  def track_llm_request
    Event.create!(
      category: "llm",
      action: "request",
      severity: "info",
      payload: {
        input: input,
        agent: agent_name,
        agent_version: version,
        model: @current_model&.external_id,
        hyperparams: hyperparams
      },
      session_id: Current.session_id,
      request_id: Current.request_id,
      job_id: Current.job_id
    )
  end

  def track_llm_response
    return unless @last_response

    Event.create!(
      category: "llm",
      action: "response",
      severity: "info",
      payload: filter_response_payload(@last_response.raw),
      session_id: Current.session_id,
      request_id: Current.request_id,
      job_id: Current.job_id
    )
  end

  def filter_response_payload(raw)
    return {} unless raw.is_a?(Faraday::Response)

    filtered_body = raw.body.deep_dup
    # Remove content from choices[].message.content
    if filtered_body["choices"].is_a?(Array)
      filtered_body["choices"].each do |choice|
        choice["message"]&.delete("content") if choice["message"].is_a?(Hash)
      end
    end

    { input: input, status: raw.status, headers: raw.headers, body: filtered_body }
  end

  def tools
    @current_version.tools.map { |tool_name| "Agent::Tool::#{tool_name}".constantize }
  end
end
