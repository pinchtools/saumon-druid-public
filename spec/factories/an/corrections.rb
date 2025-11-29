FactoryBot.define do
  factory :an_correction, class: 'An::Correction' do
    association :correctable, factory: :an_stakeholder

    transient do
      field_name { 'occupation' }
      before_value { 'Old occupation' }
      after_value { 'New occupation' }
      api_value { 'Old occupation' }
    end

    correction_changes do
      {
        field_name => {
          'before' => before_value,
          'after' => after_value,
          'api_value' => api_value
        }
      }
    end

    reason { 'Factory-generated correction' }
    correction_type { 'automatic' }
    session_id { nil }

    trait :for_term do
      association :correctable, factory: :an_term
    end

    trait :for_body do
      association :correctable, factory: :an_body
    end

    trait :manual do
      correction_type { 'manual' }
      reason { 'Manual correction via console' }
      session_id { nil }
    end

    trait :with_session do
      session_id { "session_#{SecureRandom.hex(8)}" }
    end
  end
end
