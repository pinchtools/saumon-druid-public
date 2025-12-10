FactoryBot.define do
  factory :an_term, class: "An::Term" do
    association :an_stakeholder, factory: :an_stakeholder
    association :an_body, factory: :an_body
    sequence(:uid) { |n| "PM#{n}" }
    legislature { "16" }
    start_date { 1.year.ago }
    end_date { 1.week.ago }
    publish_date { 1.year.ago }
    assumption_date { 1.year.ago }
    role_rank { 1 }
    main { false }
    origin { "Election" }
    end_reason { nil }
    seat { "001" }
    collaborators { [] }
    constituency { nil }
    deputy_term { nil }
    capacity { "deputy" }
    label { "Député" }

    trait :with_constituency do
      association :constituency, factory: :an_body
    end

    trait :with_deputy_term do
      association :deputy_term, factory: :an_term
    end

    trait :main_term do
      main { true }
    end

    trait :major_responsibility do
      an_body { create(:an_body, :high_level) }
    end

    trait :ended do
      end_date { 1.month.ago }
      end_reason { "Resignation" }
    end
  end
end
