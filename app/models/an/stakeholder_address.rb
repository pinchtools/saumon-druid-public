class An::StakeholderAddress < ApplicationRecord
  belongs_to :an_stakeholder, class_name: "An::Stakeholder", inverse_of: :an_stakeholder_addresses

  validates :uid, presence: true, uniqueness: true
  validates :an_stakeholder_id, presence: true
end
