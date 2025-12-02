class AddGenderToAnStakeholder < ActiveRecord::Migration[8.1]
  def change
    add_column :an_stakeholders, :gender, :string
  end
end
