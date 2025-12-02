class AddLabelToAnTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :an_terms, :label, :string, limit: 800
  end
end
