class Agent::QueryPlannerV2 < Agent::BaseAgent
  agent_name "query_planner_v2"

  protected

  def perform_call
    chat.on_tool_call do |tool_call|
      track_tool_use("tool_call", { name: tool_call, arguments: tool_call.arguments })
    end.on_tool_result do |result|
      track_tool_use("tool_result", { note: result[:note] })
      # Called after the tool returns its result
    end

    response = ask(input_validator.question)
    parse_and_validate_json_response(response)
  end

  def handle_tool_response_retry(data, original_response)
    # The model returned data (likely from a tool call) instead of the expected format
    # Retry once with this data as additional context to help resolve ambiguous terms

    retry_message = build_retry_message(data, original_response)
    response = ask(retry_message)

    # Parse with retry_count: 1 to prevent infinite retries
    parse_and_validate_json_response(response, retry_count: 1)
  end

  private

  def build_retry_message(data, original_response)
    formatted_data = if data.is_a?(Hash)
      JSON.pretty_generate(data[:content])
    else
      data.to_s
    end

    <<~MESSAGE
      A tool was called to help resolve ambiguous terms in the query. Here is the additional data returned:

      #{formatted_data}

      Please use this information to construct your query plan in the correct JSON format with the required structure (steps, confidence, confidence_rationale).
    MESSAGE
  end

  def track_tool_use(action, payload)
    track_event(
      category: "agent",
      action: action,
      payload: payload
    )
  end
end
