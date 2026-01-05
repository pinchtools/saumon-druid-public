# frozen_string_literal: true

module An::Body::QueryActions
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) {
      where("label ILIKE ?", "%#{sanitize_sql_like(query)}%")
    }

    scope :with_members, -> { joins(:an_terms).includes(an_terms: :an_stakeholder) }

    scope :by_political_orientation, ->(orientation) {
      where(political_camp: orientation)
    }
  end
end
