class CreateAnBodies < ActiveRecord::Migration[8.0]
  def change
    create_table :an_bodies do |t|
      t.references :an_body_type, null: false, foreign_key: true
      t.string :uid, null: false
      t.string :label
      t.string :label_abbr
      t.string :label_code
      t.datetime :start_date
      t.datetime :end_date
      t.datetime :deliver_date
      t.string :chamber
      t.string :regime
      t.string :legislature
      t.string :number
      t.string :province
      t.string :department_code

      t.references :parent, null: true, foreign_key: { to_table: :an_bodies }
      t.timestamps
    end

    add_index :an_bodies, :uid, unique: true
  end
end
