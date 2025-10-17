class AddHierarchyLevelToAnBodyTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :an_body_types, :hierarchy_level, :integer, default: nil
  end
end
