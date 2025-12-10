class An::Search < ApplicationRecord
  belongs_to :searchable, polymorphic: true

  has_neighbors :embedding

  scope :fts_search, ->(query) {
    normalized_query = normalize_query(query)
    fts_condition_node = fts_condition_node(normalized_query)
    rank_node = fts_rank_node(normalized_query)

    where(fts_condition_node)
      .order(rank_node.desc)
  }

  scope :trigram_search, ->(query) {
    normalized_query = normalize_query(query)
    similarity_node = trigram_similarity_node(normalized_query)

    where(similarity_node.gt(0.6))
      .order(similarity_node.desc)
  }

  scope :lexical_search, ->(query, fts_weight: 0.7, trigram_weight: 0.3) do
    normalized_query = normalize_query(query)

    fts_node = fts_rank_node(normalized_query)
    trigram_node = trigram_similarity_node(normalized_query)
    score_node = combined_score_node(fts_node, trigram_node, fts_weight, trigram_weight)

    select(arel_table[Arel.star], score_node.as("combined_score"))
      .where(trigram_node.gt(0.6))
      .order(score_node.desc)
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

  def self.fts_condition_node(query)
    Arel::Nodes::InfixOperation.new("@@",
      arel_table[:fts],
      Arel::Nodes::NamedFunction.new("plainto_tsquery", [
        Arel::Nodes.build_quoted("french"),
        Arel::Nodes.build_quoted(query)
      ])
    )
  end

  def self.fts_rank_node(query)
    Arel::Nodes::NamedFunction.new("ts_rank_cd", [
      arel_table[:fts],
      Arel::Nodes::NamedFunction.new("plainto_tsquery", [
        Arel::Nodes.build_quoted("french"),
        Arel::Nodes.build_quoted(query)
      ])
    ])
  end

  def self.trigram_similarity_node(normalized_query)
    Arel::Nodes::NamedFunction.new("word_similarity", [
      Arel::Nodes.build_quoted(normalized_query),
      arel_table[:trigram]
    ])
  end

  def self.combined_score_node(fts_rank_node, trigram_similarity_node, fts_weight, trigram_weight)
    Arel::Nodes::Addition.new(
      Arel::Nodes::Multiplication.new(Arel::Nodes.build_quoted(fts_weight), fts_rank_node),
      Arel::Nodes::Multiplication.new(Arel::Nodes.build_quoted(trigram_weight), trigram_similarity_node)
    )
  end
end
