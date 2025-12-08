class SetHnswEfSearch < ActiveRecord::Migration[8.1]
  def up
    # Set ef_search for all HNSW indexes in this session
    # 100-150 excellent accuracy with low overhead
    execute "ALTER ROLE postgres SET hnsw.ef_search = 100;"
  end

  def down
    execute "ALTER ROLE postgres SET hnsw.ef_search = 10;"
  end
end
