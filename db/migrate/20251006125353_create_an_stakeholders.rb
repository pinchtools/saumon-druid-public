class CreateAnStakeholders < ActiveRecord::Migration[8.0]
  def change
    create_table :an_stakeholders do |t|
      t.string :uid
      t.string :civility
      t.string :first_name
      t.string :last_name
      t.date :birth_date
      t.string :birth_city
      t.string :birth_province
      t.date :death_date
      t.string :occupation
      t.string :occupation_category
      t.string :occupation_family
      t.string :emails, array: true, default: []
      t.string :urls, array: true, default: []
      t.string :phone_numbers, array: true, default: []

      t.timestamps
    end

    add_index :an_stakeholders, :uid, unique: true
    add_index :an_stakeholders, :first_name
    add_index :an_stakeholders, :last_name
    add_index :an_stakeholders, :birth_date
    add_index :an_stakeholders, :occupation
    add_index :an_stakeholders, :occupation_category
    add_index :an_stakeholders, :occupation_family
  end
end
