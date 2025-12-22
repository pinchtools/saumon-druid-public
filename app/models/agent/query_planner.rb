class Agent::QueryPlanner < Agent::BaseAgent
  agent_name "query_planner"


  def call(input)
    super

    response = chat.ask(input_validator.question)
    parse_and_validate_json_response(response)
  end
end
