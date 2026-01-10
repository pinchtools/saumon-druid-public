class AddDebugIndexesToEvents < ActiveRecord::Migration[8.1]
  def change
    add_index :events, "(payload->>'conversation_id'), created_at",
              using: :btree,
              name: "index_events_on_payload_conversation_id"

    add_index :events, "(payload->>'message_id'), created_at",
              using: :btree,
              name: "index_events_on_payload_message_id"

    add_index :events, "(payload->>'trace_id'), created_at",
              using: :btree,
              name: "index_events_on_payload_trace_id"
  end
end
