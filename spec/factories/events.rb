FactoryBot.define do
  factory :event do
    category { "import" }
    action { "started" }
    severity { "info" }
    payload { {} }
    session_id { SecureRandom.uuid }
    request_id { SecureRandom.uuid }

    trait :error do
      severity { "error" }
      payload { { error: "Something went wrong" } }
    end

    trait :with_eventable do
      association :eventable, factory: :an_stakeholder
    end

    trait :import_completed do
      category { "import" }
      action { "completed" }
      payload { { entity_type: "stakeholders", processed: 100, created: 50, updated: 40, failed: 10 } }
    end
  end
end
