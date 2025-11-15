FactoryBot.define do
  factory :agent_version_llm_model do
    agent_version
    llm_model

    sequence(:priority) { |n| n }
  end
end
