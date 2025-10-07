FactoryBot.define do
  factory :an_body_type, class: "An::BodyType" do
    sequence(:code) { |n| "BODY_TYPE_#{n}" }
    unique_per_date { false }
    single_assignment_per_actor { false }
    external { false }
    trans_legislature { false }
    local { false }
    has_substitute { false }
  end
end
