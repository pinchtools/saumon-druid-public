class An::Search < ApplicationRecord
  belongs_to :searchable, polymorphic: true

  has_neighbors :embedding

  scope :fts_search, ->(query) {
    normalized_query = normalize_query(query)
    where("fts @@ plainto_tsquery('french', ?)", normalized_query)
      .order(Arel.sql("ts_rank_cd(fts, plainto_tsquery('french', #{connection.quote(normalized_query)})) DESC"))
  }

  scope :trigram_search, ->(query) {
    normalized_query = normalize_query(query)
    where("word_similarity(?, trigram) > 0.6", normalized_query)
      .order(Arel.sql("word_similarity(#{connection.quote(normalized_query)}, trigram) DESC"))
  }

  scope :lexical_search, ->(query, fts_weight: 0.7, trigram_weight: 0.3) do
    normalized_query = normalize_query(query)

    fts_sql      = fts_rank_sql(normalized_query)
    trigram_sql  = trigram_similarity_sql(normalized_query)
    score_sql    = combined_score_sql(fts_sql, trigram_sql, fts_weight, trigram_weight)

    select("#{table_name}.*, #{score_sql} AS combined_score").
      where("#{trigram_sql} > 0.6").
      order(Arel.sql("#{score_sql} DESC"))
  end

  def self.semantic_search(query, limit: 10)
    embedding = Llm::OpenrouterEmbeddingService.new.embed(query)

    nearest_neighbors(:embedding, embedding&.first, distance: "cosine").limit(limit)
  rescue Llm::OpenrouterEmbeddingService::EmbeddingError => e
    Rails.event.notify_with_tags("llm.embedding-server-error", { error: e.message }, tags: { severity: :error })

    []
  end

  def update_fts(content)
    sanitized = content.parameterize(separator: " ")
    self.fts = self.class.connection.execute(
      "SELECT to_tsvector('french', #{self.class.connection.quote(sanitized)})"
    ).first["to_tsvector"]
  end

  def update_trigram(content)
    self.trigram = content.parameterize(separator: " ")
  end

  def update_embedding(embedding)
    self.embedding = embedding
  end

  private

  def self.normalize_query(query)
    query.to_s.parameterize(separator: " ")
  end

  def self.fts_rank_sql(query)
    sanitized = connection.quote(query)
    "ts_rank_cd(fts, plainto_tsquery('french', #{sanitized}))"
  end

  def self.trigram_similarity_sql(normalized_query)
    sanitized = connection.quote(normalized_query)
    "word_similarity(#{sanitized}, trigram)"
  end

  def self.combined_score_sql(fts_sql, trigram_sql, fts_weight, trigram_weight)
    "(#{fts_weight} * #{fts_sql}) + (#{trigram_weight} * #{trigram_sql})"
  end
end
