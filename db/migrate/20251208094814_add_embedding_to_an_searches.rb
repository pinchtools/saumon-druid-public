class AddEmbeddingToAnSearches < ActiveRecord::Migration[8.1]
  def up
    # Add vector column (1024 dimensions)
    add_column :an_searches, :embedding, :vector, limit: 1024

    # Create HNSW index with recommended parameters:
    # - vector_cosine_ops: use cosine similarity
    # - m: 24 -> number of bi-directional links per HNSW node (higher = better accuracy, slightly slower insert)
    # - ef_construction: 300 -> search depth during index construction (higher = better accuracy, slower build)
    # The index will allow fast nearest-neighbor search on the embedding column
    execute <<-SQL.squish
      CREATE INDEX index_an_searches_on_embedding
      ON an_searches
      USING hnsw (embedding vector_cosine_ops)
      WITH (m = 24, ef_construction = 300);
    SQL
  end

  def down
    remove_column :an_searches, :embedding
  end
end
