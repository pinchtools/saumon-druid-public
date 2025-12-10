class CreateAnSearches < ActiveRecord::Migration[8.1]
  def up
    create_table :an_searches, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :searchable, polymorphic: true, null: false
      t.tsvector :fts
      t.text :trigram

      t.timestamps
    end

    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    add_index :an_searches, :fts, using: :gin
    add_index :an_searches, :trigram, using: :gin, opclass: :gin_trgm_ops
    add_index :an_searches, [ :searchable_type, :searchable_id ], unique: true
  end

  def down
    drop_table :an_searches
  end
end
