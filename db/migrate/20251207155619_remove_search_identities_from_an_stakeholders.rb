class RemoveSearchIdentitiesFromAnStakeholders < ActiveRecord::Migration[8.1]
  def up
    remove_column :an_stakeholders, :search_identity_fts, :tsvector
    remove_column :an_stakeholders, :search_identity_trgm, :text
  end

  def down
    add_column :an_stakeholders, :search_identity_fts, :tsvector
    add_column :an_stakeholders, :search_identity_trgm, :text

    add_index :an_stakeholders, :search_identity_fts, using: :gin
    add_index :an_stakeholders, :search_identity_trgm, using: :gin, opclass: :gin_trgm_ops
  end
end
