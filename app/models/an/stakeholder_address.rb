class An::StakeholderAddress < ApplicationRecord
  ADDRESS_TYPES = %w[assembly other constituency] # Order matter

  belongs_to :an_stakeholder, class_name: "An::Stakeholder", inverse_of: :an_stakeholder_addresses

  validates :uid, presence: true, uniqueness: true
  validates :an_stakeholder_id, presence: true
  validates :address_type, presence: true, inclusion: { in: ADDRESS_TYPES }
end
