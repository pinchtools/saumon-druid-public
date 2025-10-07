FactoryBot.define do
  factory :an_stakeholder, class: "An::Stakeholder" do
    sequence(:uid) { |n| "PA#{n}" }
    civility { "M." }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    birth_date { Faker::Date.between(from: 60.years.ago, to: 25.years.ago) }
    birth_city { Faker::Address.city }
    birth_province { "France" }
    death_date { nil }
    occupation { "Député" }
    occupation_category { "Politique" }
    occupation_family { "Élus" }
    emails { [ Faker::Internet.email ] }
    urls { [ Faker::Internet.url ] }
    phone_numbers { [ Faker::PhoneNumber.phone_number ] }

    trait :deceased do
      death_date { Faker::Date.between(from: 5.years.ago, to: 1.year.ago) }
    end
  end
end
