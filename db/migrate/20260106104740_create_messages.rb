# frozen_string_literal: true

class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :conversation, null: false, foreign_key: true, type: :uuid
      t.string :role, null: false
      t.text :content
      t.jsonb :metadata, null: false, default: {}
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :messages, %i[conversation_id created_at]
    add_index :messages, :role
    add_index :messages, :status

    add_check_constraint :messages,
                         "role IN ('user', 'assistant')",
                         name: "check_message_role"

    add_check_constraint :messages,
                         "status IN ('pending', 'processing', 'completed', 'failed')",
                         name: "check_message_status"
  end
end
