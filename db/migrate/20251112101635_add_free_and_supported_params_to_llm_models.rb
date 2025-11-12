class AddFreeAndSupportedParamsToLlmModels < ActiveRecord::Migration[8.1]
  def change
    add_column :llm_models, :free, :boolean, default: false
    add_column :llm_models, :supported_params, :jsonb, default: []
  end
end
