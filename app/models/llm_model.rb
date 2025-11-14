class LlmModel < ApplicationRecord
  TIERS = %w[tiny small medium strong top].freeze

  validates :external_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :family, presence: true
  validates :provider, presence: true

  validates :tier,
            inclusion: { in: TIERS },
            allow_nil: true,
            allow_blank: false
end
