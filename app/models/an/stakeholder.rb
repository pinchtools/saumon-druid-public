class An::Stakeholder < ApplicationRecord
  has_many :an_stakeholder_addresses, class_name: "An::StakeholderAddress", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :an_terms, class_name: "An::Term", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy
  has_many :an_substitutes, class_name: "An::Substitute", foreign_key: :an_stakeholder_id, inverse_of: :an_stakeholder, dependent: :destroy

  validates :uid, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true

  before_save :update_fts_search
  before_save :update_trigram_search

  scope :fts_search, ->(query) {
    where("search_identity_fts @@ plainto_tsquery('french', ?)", query)
      .order(safe_sql_order("ts_rank(search_identity_fts, plainto_tsquery('french', %s)) DESC", query))
  }

  scope :trigram_search, ->(query) {
    normalized_query = query.parameterize(separator: " ")
    where("word_similarity(?, search_identity_trgm) > 0.2", normalized_query)
      .order(safe_sql_order("word_similarity(%s, search_identity_trgm) DESC", normalized_query))
  }

  scope :search, ->(query) {
    normalized_query = query.parameterize(separator: " ")
    where(
      "search_identity_fts @@ plainto_tsquery('french', ?) OR word_similarity(?, search_identity_trgm) > 0.2",
      query, normalized_query
    ).order(
      safe_sql_order(
        "ts_rank(search_identity_fts, plainto_tsquery('french', %s)) DESC, word_similarity(%s, search_identity_trgm) DESC",
        query, normalized_query
      )
    )
  }

  # private

  def self.safe_sql_order(template, *values)
    sanitized_values = values.map { |v| connection.quote(v) }
    Arel.sql(template % sanitized_values)
  end
  def build_search_text
    name = [first_name, last_name].join(" ")
    current_main_position = an_terms.main.active.by_hierarchy.first&.full_label
    other_active_positions = an_terms.main.active.by_hierarchy.offset(1).limit(3).map(&:full_label).join(" ")
    past_positions = an_terms.main.past.by_hierarchy.limit(2).map(&:full_label).join(" ")

    [
      3.times.map { name },
      3.times.map { current_main_position }.compact,
      2.times.map { other_active_positions }.reject(&:blank?),
      past_positions,
      occupation
    ].flatten.compact.join(" ")
  end

  def update_fts_search
    self.search_identity_fts = ActiveRecord::Base.connection.execute(
      "SELECT to_tsvector('french', #{ActiveRecord::Base.connection.quote(build_search_text)})"
    ).first['to_tsvector']
  end

  def update_trigram_search
    self.search_identity_trgm = build_search_text.parameterize(separator: " ")
  end
end
