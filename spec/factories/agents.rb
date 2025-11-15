FactoryBot.define do
  factory :agent do
    name { Faker::Name.name }
  end
end
