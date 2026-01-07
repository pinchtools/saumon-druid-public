FactoryBot.define do
  factory :conversation do
    status { Conversation::STATUS_ACTIVE }
    title { nil }
    metadata { {} }
    session_id { SecureRandom.uuid }
  end
end
