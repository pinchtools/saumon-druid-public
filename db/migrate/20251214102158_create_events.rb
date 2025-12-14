class CreateEvents < ActiveRecord::Migration[8.1]
  def up
    # Create table without Rails-managed primary key for TimescaleDB compatibility
    # TimescaleDB requires unique indexes to include the partitioning column
    create_table :events, id: false do |t|
      t.uuid :id, null: false, default: -> { "uuidv7()" }

      t.timestamptz :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.string :category, null: false  # import, health, data, system
      t.string :action, null: false    # started, completed, failed, etc.
      t.string :severity, null: false, default: "info"  # debug, info, warn, error

      t.string :eventable_type
      t.bigint :eventable_id

      t.bigint :actor_id
      t.string :actor_type  # User, System, Job

      # Flexible metadata storage
      t.jsonb :payload, null: false, default: {}

      # Correlation IDs for distributed tracing
      t.uuid :session_id      # Groups related events (e.g., import session)
      t.string :request_id    # Rails request ID for HTTP correlation
      t.string :job_id        # ActiveJob ID for job correlation
    end

    # TimescaleDB: Convert to hypertable partitioned by created_at
    execute <<-SQL
      SELECT create_hypertable('events', 'created_at',
        chunk_time_interval => INTERVAL '1 day',
        if_not_exists => TRUE
      );
    SQL

    # Indexes for common query patterns
    # Note: id index includes created_at for hypertable compatibility
    add_index :events, [ :id, :created_at ], unique: true
    add_index :events, [ :category, :action, :created_at ]
    add_index :events, [ :eventable_type, :eventable_id, :created_at ]
    add_index :events, [ :session_id, :created_at ]
    add_index :events, [ :severity, :created_at ], where: "severity IN ('warn', 'error')"
    add_index :events, :payload, using: :gin

    # TimescaleDB: Set up 90-day retention policy
    execute <<-SQL
      SELECT add_retention_policy('events', INTERVAL '90 days', if_not_exists => TRUE);
    SQL

    # TimescaleDB: Enable compression after 7 days
    execute <<-SQL
      ALTER TABLE events SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'category, action',
        timescaledb.compress_orderby = 'created_at DESC'
      );
    SQL

    execute <<-SQL
      SELECT add_compression_policy('events', INTERVAL '7 days', if_not_exists => TRUE);
    SQL
  end

  def down
    # Remove policies before dropping
    execute "SELECT remove_retention_policy('events', if_exists => TRUE);"
    execute "SELECT remove_compression_policy('events', if_exists => TRUE);"
    drop_table :events
  end
end
