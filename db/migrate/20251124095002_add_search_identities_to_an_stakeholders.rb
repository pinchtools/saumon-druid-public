class AddSearchIdentitiesToAnStakeholders < ActiveRecord::Migration[8.1]
  def change
    add_column :an_stakeholders, :search_identity_fts, :tsvector
    add_column :an_stakeholders, :search_identity_trgm, :text

    # FTS index
    execute <<~SQL
      CREATE INDEX idx_an_stakeholders_fts
      ON an_stakeholders USING gin(search_identity_fts);
    SQL

    # Trigram index
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')
    execute <<~SQL
      CREATE INDEX idx_an_stakeholders_trgm
      ON an_stakeholders USING gin(search_identity_trgm gin_trgm_ops);
    SQL
  end
end
