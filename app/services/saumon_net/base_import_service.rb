module SaumonNet
  class BaseImportService
    include ActiveSupport::Benchmarkable

    attr_reader :entity_type, :session_id, :stats

    def initialize(entity_type)
      @entity_type = entity_type
      @session_id = SecureRandom.uuid
      @stats = ImportStats.new
      configure_saumon_net
    end

    def import_all
      logger.info({ message: "Starting import", component: SaumonNet::COMPONENT, session_id: session_id, entity_type: entity_type })

      import_entities

      log_final_stats
      record_successful_import
      stats
    end

    def import_since(date)
      logger.info({ message: "Starting incremental import", component: SaumonNet::COMPONENT, session_id: session_id, entity_type: entity_type, since: date })

      import_entities(since: date)

      log_final_stats
      record_successful_import
      stats
    end

    private

    def import_entities(since: nil)
      batch_count = 0

      benchmark "Import #{entity_type} entities" do
        SaumonNet::Entity.list_all(type: entity_type, since: since) do |entities|
          batch_count += 1
          process_batch(entities, batch_count)
        end
      end
    rescue => e
      logger.error({ message: "Import failed", component: SaumonNet::COMPONENT, session_id: session_id, error: e.message, backtrace: e.backtrace })
      Sentry.capture_exception(e, extra: { session_id: session_id, entity_type: entity_type })
      raise
    end

    def process_batch(entities, batch_number)
      logger.info({ message: "Processing batch", component: SaumonNet::COMPONENT, session_id: session_id, batch: batch_number, count: entities.size })

      entities.each do |entity_data|
        process_entity(entity_data)
      rescue => e
        stats.increment_failed
        logger.error({ message: "Failed to process entity",
          component: SaumonNet::COMPONENT,
          session_id: session_id,
          entity_id: entity_data["uid"],
          error: e.message
        })

        Sentry.capture_exception(e, extra: {
          session_id: session_id,
          entity_type: entity_type,
          entity_data: entity_data
        })
      end

      log_batch_stats(batch_number)
    end

    def process_entity(entity_data)
      stats.increment_processed

      # Parse file content if file_url is present
      enhanced_entity_data = parse_file_content(entity_data)

      mapped_attributes = map_entity_attributes(enhanced_entity_data)
      record = find_or_initialize_record(mapped_attributes)

      if record.new_record?
        record.save!
        stats.increment_created
        logger.debug({ message: "Created record", component: SaumonNet::COMPONENT, session_id: session_id, uid: entity_data["uid"] })
        perform_additional_operations(record, enhanced_entity_data, :created)
      elsif record.changed?
        record.save!
        stats.increment_updated
        logger.debug({ message: "Updated record", component: SaumonNet::COMPONENT, session_id: session_id, uid: entity_data["uid"] })
        perform_additional_operations(record, enhanced_entity_data, :updated)
      else
        stats.increment_skipped
        logger.debug({ message: "Skipped unchanged record", component: SaumonNet::COMPONENT, session_id: session_id, uid: entity_data["uid"] })
        perform_additional_operations(record, enhanced_entity_data, :skipped)
      end
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

      logger.info({ message: "Batch progress",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        batch: batch_number,
        processed: stats.processed,
        created: stats.created,
        updated: stats.updated,
        skipped: stats.skipped,
        failed: stats.failed
      })
    end

    def log_final_stats
      logger.info({ message: "Import completed",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        entity_type: entity_type,
        total_processed: stats.processed,
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
          logger.warn({ message: "Failed to fetch file content",
            component: SaumonNet::COMPONENT,
            session_id: session_id,
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
        logger.error({ message: "Error parsing file content",
          component: SaumonNet::COMPONENT,
          session_id: session_id,
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
end
