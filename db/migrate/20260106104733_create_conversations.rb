# frozen_string_literal: true

class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :status, null: false, default: "active"
      t.string :title, limit: 255
      t.jsonb :metadata, null: false, default: {}
      t.uuid :session_id

      t.timestamps
    end

    add_index :conversations, :status
    add_index :conversations, :session_id
    add_index :conversations, :created_at

    add_check_constraint :conversations,
                         "status IN ('active', 'completed', 'failed', 'cancelled')",
                         name: "check_conversation_status"
  end
end
