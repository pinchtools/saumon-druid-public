class AddCurrentAgentVersionToAgents < ActiveRecord::Migration[8.1]
  def change
    add_reference :agents, :current_agent_version, foreign_key: { to_table: :agent_versions }
  end
end
