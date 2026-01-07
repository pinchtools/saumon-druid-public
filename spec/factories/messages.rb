FactoryBot.define do
  factory :message do
    conversation
    role { Message::ROLE_USER }
    content { Faker::Lorem.sentence }
    status { Message::STATUS_COMPLETED }
    metadata { {} }

    trait :user do
      role { Message::ROLE_USER }
    end

    trait :assistant do
      role { Message::ROLE_ASSISTANT }
    end

    trait :pending do
      status { Message::STATUS_PENDING }
    end

    trait :processing do
      status { Message::STATUS_PROCESSING }
    end

    trait :completed do
      status { Message::STATUS_COMPLETED }
    end

    trait :failed do
      status { Message::STATUS_FAILED }
    end
  end
end
