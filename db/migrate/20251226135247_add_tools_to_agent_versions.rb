class AddToolsToAgentVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_versions, :tools, :jsonb, default: [], null: false
  end
end
