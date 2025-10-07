FactoryBot.define do
  factory :an_stakeholder_address, class: "An::StakeholderAddress" do
    association :an_stakeholder, factory: :an_stakeholder
    sequence(:uid) { |n| "AD#{n}" }
    address_1 { Faker::Address.street_address }
    address_2 { Faker::Address.secondary_address }
    street_name { Faker::Address.street_name }
    street_number { Faker::Address.building_number }
    post_code { Faker::Address.postcode }
    city { Faker::Address.city }
    weight { 1 }
  end
end
