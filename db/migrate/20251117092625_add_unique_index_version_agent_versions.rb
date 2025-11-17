class AddUniqueIndexVersionAgentVersions < ActiveRecord::Migration[8.1]
  def change
    add_index :agent_versions, [ :agent_id, :version ], unique: true
  end
end
