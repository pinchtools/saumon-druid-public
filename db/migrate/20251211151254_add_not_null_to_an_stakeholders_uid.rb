class AddNotNullToAnStakeholdersUid < ActiveRecord::Migration[8.1]
  def change
    change_column_null :an_stakeholders, :uid, false
  end
end
