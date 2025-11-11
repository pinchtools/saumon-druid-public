class CreateLlmModels < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_models do |t|
      t.string "name", null: false              # gpt-4o-mini
      t.string "external_id", null: false
      t.string "family", null: false            # openai, mistralai
      t.string "provider", null: false          # openrouter, openai, self-hosted
      t.string "tier"                           # flagship, strong, medium, small, tiny
      t.jsonb "categories", default: []         # embedding, chat, classification, summerization
      t.integer "context_window"                # tokens
      t.integer "output_size"                   # tokens
      t.jsonb "capabilities", default: []       # batch, function_calling, structured_output, streaming
      t.date "knowledge_cutoff"                 # last refresh date
      t.decimal "input_cost", precision: 10, scale: 6 # per millions
      t.decimal "output_cost", precision: 10, scale: 6 # per millions
      t.boolean "available", default: true
      t.timestamps
    end

    add_index :llm_models, :external_id, unique: true
    add_index :llm_models, :family
    add_index :llm_models, :tier
  end
end
