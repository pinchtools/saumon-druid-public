class CreateAgentVersionLlmModels < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_version_llm_models do |t|
      t.references :agent_version, null: false, foreign_key: true
      t.references :llm_model, null: false, foreign_key: true
      t.integer :priority, default: 1, null: false
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :agent_version_llm_models, [ :agent_version_id, :llm_model_id ], unique: true
    add_index :agent_version_llm_models, [ :agent_version_id, :priority ], unique: true
  end
end
