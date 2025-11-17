class AlterDefaultVersionAgentVersions < ActiveRecord::Migration[8.1]
  def change
    change_column_default :agent_versions, :version, from: nil, to: 1
  end
end
