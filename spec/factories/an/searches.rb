FactoryBot.define do
  factory :an_search, class: "An::Search" do
    association :searchable, factory: :an_stakeholder
    fts { nil }
    trigram { nil }
    embedding { nil }
  end
end
