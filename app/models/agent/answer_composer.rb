# frozen_string_literal: true

# Answer Composer Agent
# Generates French language responses from query results about the French National Assembly
class Agent::AnswerComposer < Agent::BaseAgent
  agent_name "answer_composer"

  MAX_INLINE_RESULTS = 10
  SAMPLE_SIZE = 5

  protected

  def perform_call
    @start_time = Time.current

    track_composition_started
    chat
    response = ask(build_prompt)
    result = parse_and_validate_json_response(response)
    track_composition_completed(result)
    result
  rescue StandardError => e
    track_composition_error(e)
    raise
  end

  private

  def build_prompt
    <<~PROMPT
      User's original question:
      #{input_validator.question}

      Query execution results:
      The following data comes from executing a multi-step query plan.
      Each section corresponds to a step in the plan, identified by its step ID.

      #{format_results}

      Query planner confidence level: #{input_validator.confidence || "not specified"}/5
      (This indicates how confidently the query planner understood and decomposed the user's question)
    PROMPT
  end

  def format_results
    results = input_validator.results
    return "No results available" if results.blank?

    results.filter_map do |step_id, data|
      next if data.blank?

      formatted_data = data.is_a?(Array) ? format_array_results(data) : data.to_json
      "=== Step: #{step_id} ===\n#{formatted_data}"
    end.join("\n\n")
  end

  def format_array_results(data)
    return "No data" if data.empty?

    if data.size <= MAX_INLINE_RESULTS
      data.map { |item| format_item(item) }.join("\n")
    else
      sample = data.first(SAMPLE_SIZE)
      formatted_sample = sample.map { |item| format_item(item) }.join("\n")
      "#{data.size} results found. Here are the first #{SAMPLE_SIZE}:\n#{formatted_sample}"
    end
  end

  def format_item(item)
    return item.to_s unless item.is_a?(Hash)

    item.compact.map { |k, v| "#{k}: #{v}" }.join(", ")
  end

  # Event tracking methods

  def track_composition_started
    track_composition_event("started", payload: {
      question: input_validator.question.truncate(200),
      result_count: input_validator.results&.size || 0,
      confidence: input_validator.confidence
    })
  end

  def track_composition_completed(result)
    track_composition_event("completed", payload: {
      duration_ms: elapsed_time_ms,
      answer_length: result["answer"]&.length || 0,
      has_confidence_note: result["confidence_note"].present?
    })
  end

  def track_composition_error(exception)
    track_composition_event("error", severity: :error, payload: {
      duration_ms: elapsed_time_ms,
      error_class: exception.class.name,
      error_message: exception.message.truncate(500)
    })
  end

  def track_composition_event(action, severity: :info, payload: {})
    track_event(
      category: "agent",
      action: "answer_composer.#{action}",
      severity: severity,
      payload: payload
    )
  end

  def elapsed_time_ms
    return 0 unless @start_time

    ((Time.current - @start_time) * 1000).round
  end
end
