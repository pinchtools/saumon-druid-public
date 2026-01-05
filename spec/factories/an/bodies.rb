FactoryBot.define do
  factory :an_body, class: "An::Body" do
    association :an_body_type, factory: :an_body_type
    sequence(:uid) { |n| "PO#{n}" }
    sequence(:label) { |n| "1er ciconscription de la Corrèze" }
    label_abbr { "19 Corrèze (1er)" }
    label_code { "CIRCO" }
    start_date { 1.year.ago }
    end_date { 1.year.from_now }
    deliver_date { Time.current }
    chamber { "Assemblée nationale" }
    regime { "5e république" }
    legislature { "16" }
    number { "1" }
    province { "France" }
    department_code { "75" }
    parent { nil }

    trait :with_parent do
      association :parent, factory: :an_body
    end

    trait :high_level do
      an_body_type { create(:an_body_type, :high_level) }
    end

    trait :political_group do
      transient do
        political_camp_value { "left" }
      end

      an_body_type { An::BodyType.find_or_create_by!(code: "GP") }
      sequence(:label) { |n| "Groupe politique #{n}" }
      political_camp { political_camp_value }
    end
  end
end
