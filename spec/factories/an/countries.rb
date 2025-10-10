FactoryBot.define do
  factory :an_country, class: "An::Country" do
    sequence(:uid) { |n| "GOP#{n}" }
    name { Faker::Address.country }
    insee_code { Faker::Address.country_code }
    insee_name { Faker::Address.country }
    iso_code { Faker::Address.country_code }
    active { true }
  end
end
