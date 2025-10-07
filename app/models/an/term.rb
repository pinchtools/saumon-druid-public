class An::Term < ApplicationRecord
  belongs_to :an_stakeholder, class_name: "An::Stakeholder", inverse_of: :an_terms
  belongs_to :an_body, class_name: "An::Body", inverse_of: :an_terms
  belongs_to :constituency, class_name: "An::Body", optional: true
  belongs_to :deputy_term, class_name: "An::Term", optional: true
  has_many :subordinate_terms, class_name: "An::Term", foreign_key: :deputy_term_id, dependent: :destroy

  validates :uid, presence: true, uniqueness: true
  validates :an_stakeholder_id, :an_body_id, presence: true
end
