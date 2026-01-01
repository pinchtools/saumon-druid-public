class An::Term < ApplicationRecord
  include Eventable
  include DateFilterable
  include An::Concerns::Searchable
  include An::Term::SearchContentBuilder

  after_commit :track_creation, on: :create
  after_commit :track_update, on: :update, if: :saved_changes?

  belongs_to :an_stakeholder, class_name: "An::Stakeholder", inverse_of: :an_terms
  belongs_to :an_body, class_name: "An::Body", inverse_of: :an_terms
  belongs_to :constituency, class_name: "An::Body", optional: true
  belongs_to :deputy_term, class_name: "An::Term", optional: true
  has_many :subordinate_terms, class_name: "An::Term", foreign_key: :deputy_term_id, dependent: :destroy
  has_many :an_substitutes, class_name: "An::Substitute", foreign_key: :an_term_id, inverse_of: :an_term, dependent: :destroy
  has_one :an_body_type, through: :an_body
  has_many :corrections, as: :correctable, class_name: "An::Correction", dependent: :destroy

  scope :main, -> { where(main: true) }
  scope :by_hierarchy, -> { joins(an_body: :an_body_type).order("an_body_types.hierarchy_level ASC") }

  scope :by_body_type, ->(*codes) {
    codes = codes.flatten
    joins(an_body: :an_body_type).where(an_body_types: { code: codes })
  }

  validates :uid, presence: true, uniqueness: true
  validates :an_stakeholder_id, :an_body_id, presence: true
  validates :label, length: { maximum: 800 }

  def role_rank_label
    case role_rank
    when 1
      I18n.t("an.term.role_rank.very_high")
    when 2..4
      I18n.t("an.term.role_rank.high")
    when 5..30
      I18n.t("an.term.role_rank.medium")
    else
      I18n.t("an.term.role_rank.low")
    end
  end

  private

  def track_creation
    track_event(:created, payload: { uid: uid })
  end

  def track_update
    track_event(:updated, payload: { uid: uid, changes: saved_changes })
  end
end
