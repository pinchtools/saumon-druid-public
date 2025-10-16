class AddAdditionalColumnsToAnBodyTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :an_body_types, :institution, :string
    add_column :an_body_types, :group, :string
    add_column :an_body_types, :selection, :string
  end
end
