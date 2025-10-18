class An::Stakeholder < ApplicationRecord
  has_many :an_stakeholder_addresses, class_name: "An::StakeholderAddress", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :an_terms, class_name: "An::Term", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :an_substitutes, class_name: "An::Substitute", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy

  validates :uid, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true
end
