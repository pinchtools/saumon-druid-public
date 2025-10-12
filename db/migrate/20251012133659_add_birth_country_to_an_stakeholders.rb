class AddBirthCountryToAnStakeholders < ActiveRecord::Migration[8.0]
  def change
    add_column :an_stakeholders, :birth_country, :string
  end
end
