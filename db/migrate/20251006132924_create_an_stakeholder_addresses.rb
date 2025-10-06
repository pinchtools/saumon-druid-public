class CreateAnStakeholderAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :an_stakeholder_addresses do |t|
      t.references :an_stakeholder, null: false, foreign_key: true

      t.string :uid, null: false
      t.string :address_1
      t.string :address_2
      t.string :street_name
      t.string :street_number
      t.string :post_code
      t.string :city
      t.integer :weight

      t.timestamps
    end

    add_index :an_stakeholder_addresses, :uid, unique: true
  end
end
