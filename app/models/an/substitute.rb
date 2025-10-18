class An::Substitute < ApplicationRecord
  belongs_to :an_term, class_name: "An::Term", inverse_of: :an_substitutes
  belongs_to :an_stakeholder, class_name: "An::Stakeholder", inverse_of: :an_substitutes

  validates :an_term_id, presence: true
  validates :an_stakeholder_id, presence: true
end
