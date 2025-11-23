class RemoveRoleCodeFromAnTerms < ActiveRecord::Migration[8.1]
  def change
    remove_column :an_terms, :role_code, :string
  end
end
