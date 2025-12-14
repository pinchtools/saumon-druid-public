class SaumonNet::BaseImportService
  include ActiveSupport::Benchmarkable
  include ServiceEventable

  attr_reader :entity_type, :stats

  def initialize(entity_type)
    @entity_type = entity_type
    @session_id = SecureRandom.uuid
    @stats = ImportStats.new
    configure_saumon_net
  end

  def import_all
    track_event(:started, category: "import", payload: { entity_type: entity_type })

    import_entities

    track_completed_event
    record_successful_import
    stats
  end

  def import_since(date)
    track_event(:incremental_started, category: "import", payload: { entity_type: entity_type, since: date.iso8601 })

    import_entities(since: date)

    track_completed_event
    record_successful_import
    stats
  end

  private

  def sanitize_entity_value(entity_value)
    return nil if entity_value.blank? || !entity_value.is_a?(String)

    entity_value
  end

  def import_entities(since: nil)
    batch_count = 0

    benchmark "Import #{entity_type} entities" do
      SaumonNet::Entity.list_all(type: entity_type, since: since) do |entities|
        batch_count += 1
        process_batch(entities, batch_count)
      end
    end
  rescue => e
    track_event(:failed, category: "import", severity: :error, payload: {
      entity_type: entity_type,
      error: e.message,
      backtrace: e.backtrace&.first(10)
    })
    raise
  end

  def process_batch(entities, batch_number)
    track_event(:batch_processing, category: "import", payload: { batch: batch_number, count: entities.size })

    entities.each do |entity_data|
      process_entity(entity_data)
    end

    log_batch_stats(batch_number)
  end

  def process_entity(entity_data)
    stats.increment_processed

    ApplicationRecord.transaction do
      enhanced_entity_data = parse_file_content(entity_data)
      mapped_attributes = map_entity_attributes(enhanced_entity_data)
      record = find_or_initialize_record(mapped_attributes)

      if record.new_record?
        record.save!
        track_event(:record_created, category: "import", severity: :debug, payload: { uid: entity_data["uid"] })
        perform_additional_operations(record, enhanced_entity_data, :created)
      elsif record.changed?
        record.save!
        track_event(:record_updated, category: "import", severity: :debug, payload: { uid: entity_data["uid"] })
        perform_additional_operations(record, enhanced_entity_data, :updated)
      else
        stats.increment_skipped
        track_event(:record_skipped, category: "import", severity: :debug, payload: { uid: entity_data["uid"] })
        perform_additional_operations(record, enhanced_entity_data, :skipped)
      end

      if record.previously_new_record?
        stats.increment_created
      else
        stats.increment_updated
      end
    end
  rescue => e
    stats.increment_failed
    track_event(:entity_processing_failed, category: "import", severity: :error, payload: {
      entity_id: entity_data["uid"],
      entity_type: entity_type,
      error: e.message,
      backtrace: e.backtrace&.first(10)
    })
  end

  def map_entity_attributes(entity_data)
    raise NotImplementedError, "Subclasses must implement map_entity_attributes"
  end

  def find_or_initialize_record(attributes)
    raise NotImplementedError, "Subclasses must implement find_or_initialize_record"
  end

  # Hook method for subclasses to perform additional operations after record save
  # Override this method in subclasses to add custom logic like creating associations
  def perform_additional_operations(record, entity_data, operation_type)
    # Default implementation does nothing
    # Subclasses can override this to perform additional operations like:
    # - Creating associations
    # - Processing nested data
    # - Triggering events
  end

  def configure_saumon_net
    SaumonNet.configure do |config|
      config.base_url = Rails.application.credentials.saumon_net&.base_url
      config.api_token = Rails.application.credentials.saumon_net&.api_token
    end
  end

  def logger
    @logger ||= Rails.logger
  end

  def log_batch_stats(batch_number)
    return unless batch_number % 10 == 0 # Log every 10 batches

    track_event(:batch_progress, category: "import", payload: {
      batch: batch_number,
      processed: stats.processed,
      created: stats.created,
      updated: stats.updated,
      skipped: stats.skipped,
      failed: stats.failed
    })
  end

  def track_completed_event
    track_event(:completed, category: "import", payload: {
      entity_type: entity_type,
      processed: stats.processed,
      created: stats.created,
      updated: stats.updated,
      skipped: stats.skipped,
      failed: stats.failed,
      success_rate: stats.success_rate
    })
  end

  def record_successful_import
    SaumonNet::HealthMonitoringService.record_successful_import(entity_type, stats)
  end

  def parse_file_content(entity_data)
    file_url = entity_data["file_url"]

    # Return original data if no file_url
    return entity_data unless file_url.present?

    begin
      # Fetch and parse the JSON file using HTTParty
      response = HTTParty.get(file_url)

      unless response.success?
        track_event(:file_fetch_failed, category: "import", severity: :warn, payload: {
          file_url: file_url,
          status_code: response.code
        })
        return entity_data
      end

      file_content = response.parsed_response

      # Extract the nested entity data (e.g., organe data from the file)
      # The structure is usually {"organe": {...}} for organe entities
      nested_data = file_content[entity_type] || file_content

      # Merge original entity data with file details
      entity_data.merge("file_details" => nested_data)

    rescue => e
      track_event(:file_parsing_error, category: "import", severity: :error, payload: {
        file_url: file_url,
        error: e.message
      })

      # Return original data on error
      entity_data
    end
  end

  class ImportStats
    attr_accessor :processed, :created, :updated, :skipped, :failed

    def initialize
      @processed = 0
      @created = 0
      @updated = 0
      @skipped = 0
      @failed = 0
    end

    def increment_processed
      @processed += 1
    end

    def increment_created
      @created += 1
    end

    def increment_updated
      @updated += 1
    end

    def increment_skipped
      @skipped += 1
    end

    def increment_failed
      @failed += 1
    end

    def success_rate
      return 100.0 if processed == 0
      ((processed - failed).to_f / processed * 100).round(2)
    end
  end
end
