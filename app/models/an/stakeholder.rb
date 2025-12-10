class An::Stakeholder < ApplicationRecord
  include An::Concerns::Searchable
  include An::Stakeholder::SearchContentBuilder

  has_many :an_stakeholder_addresses, class_name: "An::StakeholderAddress", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :an_terms, class_name: "An::Term", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :an_substitutes, class_name: "An::Substitute", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :corrections, as: :correctable, class_name: "An::Correction", dependent: :destroy

  validates :uid, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true

  def name
    [ first_name, last_name ].join(" ")
  end

  def current_top_position
    an_terms.active.by_hierarchy.first
  end

  def other_top_active_positions(offset: 1, limit: 3)
    an_terms.active.by_hierarchy.offset(offset).limit(limit)
  end

  def top_past_positions(limit: 2)
    an_terms.past.by_hierarchy.limit(limit)
  end
end
