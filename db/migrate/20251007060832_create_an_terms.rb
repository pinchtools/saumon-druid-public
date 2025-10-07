class CreateAnTerms < ActiveRecord::Migration[8.0]
  def change
    create_table :an_terms do |t|
      t.references :an_stakeholder, null: false, foreign_key: true
      t.references :an_body, null: false, foreign_key: true
      t.references :constituency, null: true, foreign_key: { to_table: :an_bodies } # when the term come from an election
      t.references :deputy_term, null: true, foreign_key: { to_table: :an_terms } # in case of deputy been replaced by his substitute

      t.string :uid, null: false
      t.string :legislature
      t.datetime :start_date
      t.datetime :end_date
      t.datetime :publish_date
      t.datetime :assumption_date
      t.integer :role_rank
      t.string :role_code
      t.boolean :main, default: false, null: false
      t.string :origin
      t.string :end_reason
      t.string :seat
      t.string :collaborators, array: true, default: []
      t.timestamps
    end

    add_index :an_terms, :uid, unique: true
  end
end
