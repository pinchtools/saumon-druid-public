FactoryBot.define do
  factory :an_term, class: "An::Term" do
    association :an_stakeholder, factory: :an_stakeholder
    association :an_body, factory: :an_body
    sequence(:uid) { |n| "PM#{n}" }
    legislature { "16" }
    start_date { 1.year.ago }
    end_date { 1.year.from_now }
    publish_date { 1.year.ago }
    assumption_date { 1.year.ago }
    role_rank { 1 }
    role_code { "DEPUTY" }
    main { false }
    origin { "Election" }
    end_reason { nil }
    seat { "001" }
    collaborators { [] }
    constituency { nil }
    deputy_term { nil }

    trait :with_constituency do
      association :constituency, factory: :an_body
    end

    trait :with_deputy_term do
      association :deputy_term, factory: :an_term
    end

    trait :main_term do
      main { true }
    end

    trait :ended do
      end_date { 1.month.ago }
      end_reason { "Resignation" }
    end
  end
end
