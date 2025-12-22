class Agent::QueryPlannerV2 < Agent::BaseAgent
  agent_name "query_planner_v2"

  def call(input)
    super

    chat
    response = ask(input_validator.question)
    parse_and_validate_json_response(response)
  end
end
