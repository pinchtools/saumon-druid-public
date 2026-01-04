# frozen_string_literal: true

module An::Stakeholder::QueryActions
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) { lexical_search(query) }

    scope :by_gender, ->(gender) { where(gender: gender) }

    scope :by_occupation, ->(occupation) {
      where("occupation ILIKE ?", "%#{sanitize_sql_like(occupation)}%")
    }

    scope :by_department, ->(department_code) {
      joins(an_terms: { constituency: :an_body_type })
        .where(an_body_types: { code: "CIRCO" })
        .where("an_bodies.department_code = ?", department_code)
        .distinct
    }

    scope :by_political_group, ->(group_name) {
      joins(an_terms: { an_body: :an_body_type })
        .where(an_body_types: { code: "GP" })
        .where("an_bodies.label ILIKE ?", "%#{sanitize_sql_like(group_name)}%")
        .distinct
    }

    # TODO: Implement proper political orientation filtering
    scope :by_political_orientation, ->(orientation) {
      joins(an_terms: { an_body: :an_body_type })
        .where(an_body_types: { code: "GP" })
        .where("an_bodies.label ILIKE ?", "%#{sanitize_sql_like(orientation)}%")
        .distinct
    }
  end
end
