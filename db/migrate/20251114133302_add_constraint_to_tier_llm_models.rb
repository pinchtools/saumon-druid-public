class AddConstraintToTierLlmModels < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :llm_models,
                         "tier IN ('tiny','small','medium','strong','top')",
                         name: "valid_tier"
  end
end
