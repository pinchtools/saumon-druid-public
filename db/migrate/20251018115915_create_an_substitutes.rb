class CreateAnSubstitutes < ActiveRecord::Migration[8.0]
  def change
    create_table :an_substitutes do |t|
      t.references :an_term, null: false, foreign_key: true
      t.references :an_stakeholder, null: false, foreign_key: true
      t.datetime :start_date
      t.datetime :end_date
      t.timestamps
    end
  end
end
