class CreateAnBodyTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :an_body_types do |t|
      t.string :code
      t.boolean :unique_per_date, default: false, null: false # True if only one such organ exists at a time
      t.boolean :single_assignment_per_actor, default: false, null: false # True if an actor can belong to at most one such organ
      t.boolean :external, default: false, null: false # True if not part of the Assembly
      t.boolean :trans_legislature, default: false, null: false # True if it persists across legislatures
      t.boolean :local, default: false, null: false # True if it’s local level
      t.boolean :has_substitute, default: false, null: false # True if nominations can include a substitute
      t.timestamps
    end

    add_index :an_body_types, :code, unique: true
  end
end
