class An::Stakeholder < ApplicationRecord
  include An::Concerns::Searchable
  include An::Stakeholder::SearchContentBuilder
  include An::Stakeholder::QueryActions
  include Eventable

  after_commit :track_creation, on: :create
  after_commit :track_update, on: :update, if: :saved_changes?

  has_many :an_stakeholder_addresses, class_name: "An::StakeholderAddress", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :an_terms, class_name: "An::Term", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :an_substitutes, class_name: "An::Substitute", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :corrections, as: :correctable, class_name: "An::Correction", dependent: :destroy

  scope :with_terms_hierarchy, -> { includes(an_terms: { an_body: :an_body_type }) }

  validates :uid, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true

  def name
    [ first_name, last_name ].join(" ")
  end

  def current_top_position
    @current_top_position ||= sorted_active_an_terms.first
  end

  def other_top_active_positions(offset: 1, limit: 3)
    terms = sorted_active_an_terms

    if terms.is_a?(ActiveRecord::Relation)
      terms.offset(offset).limit(limit)
    else
      terms[offset..(offset + limit - 1)] || []
    end
  end

  def top_past_positions(limit: 2)
    terms = sorted_past_an_terms

    if terms.is_a?(ActiveRecord::Relation)
      terms.limit(limit)
    else
      terms[0..limit - 1] || []
    end
  end

  private

  def sorted_active_an_terms
    @sorted_active_an_terms ||= if an_terms.loaded?
                                  an_terms.select { |t| t.start_date.present? && t.end_date.nil? }
                                          .sort_by { |t| t.an_body.an_body_type.hierarchy_level }
    else
                                    an_terms.active.by_hierarchy
    end
  end

  def sorted_past_an_terms
    @sorted_past_an_terms ||= if an_terms.loaded?
                                an_terms.select { |t| t.start_date.present? && t.end_date.present? }
                                        .sort_by { |t| t.an_body.an_body_type.hierarchy_level }
    else
                                  an_terms.past.by_hierarchy
    end
  end

  def track_creation
    track_event(:created, payload: { uid: uid })
  end

  def track_update
    track_event(:updated, payload: { uuid: uid, changes: saved_changes })
  end
end
