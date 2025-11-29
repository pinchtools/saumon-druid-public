class CreateAnCorrections < ActiveRecord::Migration[8.1]
  def change
    create_table :an_corrections, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :correctable, polymorphic: true, null: false, index: true
      t.jsonb :correction_changes, null: false, default: {}
      t.string :reason, null: false
      t.string :correction_type, null: false, default: 'automatic'
      t.string :session_id

      t.timestamps
    end

    add_index :an_corrections, [ :correctable_type, :correctable_id, :created_at ], name: 'idx_corrections_on_correctable_and_time'
    add_index :an_corrections, :created_at
    add_index :an_corrections, :session_id
    add_index :an_corrections, :correction_changes, using: :gin

    add_check_constraint :an_corrections,
                         "correctable_type IN ('An::Stakeholder', 'An::Term', 'An::Body')",
                         name: "check_correctable_type"
  end
end
