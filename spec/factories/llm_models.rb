FactoryBot.define do
  factory :llm_model do
    name { Faker::Name.name }
    provider { 'openai' }
    family { 'gpt-3.5-turbo' }
    sequence(:external_id) { |n| "gpt-3.#{n}-turbo-16k" }
  end
end
