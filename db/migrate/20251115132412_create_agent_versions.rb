class CreateAgentVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_versions do |t|
      t.references "agent", null: false, foreign_key: true
      t.jsonb   "instructions"
      t.jsonb   "hyperparams" # temperature, top_p, etc.
      t.integer "version", null: false
      t.timestamps
    end
  end
end
