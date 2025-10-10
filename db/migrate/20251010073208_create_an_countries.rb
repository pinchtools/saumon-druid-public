class CreateAnCountries < ActiveRecord::Migration[8.0]
  def change
    create_table :an_countries do |t|
      t.string :uid, null: false
      t.string :name, null: false
      t.string :insee_code
      t.string :insee_name
      t.string :iso_code
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :an_countries, :uid, unique: true
    add_index :an_countries, :name
  end
end
