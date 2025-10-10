class CreateAnCountries < ActiveRecord::Migration[8.0]
  def change
    create_table :an_countries do |t|
      t.string :uid, null: false
      t.string :name
      t.string :insee_code, null: false
      t.string :insee_name
      t.string :iso_code, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :an_countries, :uid, unique: true
    add_index :an_countries, :insee_code, unique: true
    add_index :an_countries, :iso_code, unique: true
    add_index :an_countries, :name
  end
end
