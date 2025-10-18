FactoryBot.define do
  factory :an_substitute, class: "An::Substitute" do
    association :an_term, factory: :an_term
    association :an_stakeholder, factory: :an_stakeholder
    start_date { 1.month.ago }
    end_date { 1.month.from_now }

    trait :active do
      start_date { 1.month.ago }
      end_date { nil }
    end

    trait :ended do
      start_date { 6.months.ago }
      end_date { 1.month.ago }
    end

    trait :future do
      start_date { 1.month.from_now }
      end_date { 3.months.from_now }
    end
  end
end
