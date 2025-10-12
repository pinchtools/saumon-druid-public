class SaumonNetImportJob < ApplicationJob
  queue_as :default

  discard_on(SaumonNet::AuthenticationError) { |job, error|  notify_discarded_job(job, error) }
  discard_on(SaumonNet::ConfigurationError) { |job, error|  notify_discarded_job(job, error) }

  def perform(entity_type, since_date = nil)
    import_service = build_import_service(entity_type)

    if since_date.present?
      parsed_date = parse_since_date(since_date)
      stats = import_service.import_since(parsed_date)
    else
      stats = import_service.import_all
    end

    track_import_metrics(entity_type, stats)

    Rails.logger.info message: "Import job completed",
                      component: SaumonNet::COMPONENT,
                      entity_type: entity_type,
                      since_date: since_date,
                      stats: stats_summary(stats)

  rescue => e
    Rails.logger.error message: "Import job failed",
                       component: SaumonNet::COMPONENT,
                       entity_type: entity_type,
                       since_date: since_date,
                       error: e.message,
                       backtrace: e.backtrace

    raise
  end

  private

  class << self
    private
    def notify_discarded_job(job, error)
      Rails.logger.warn("Discarded job #{job.job_id} because of #{error.class}")
    end
  end

  def build_import_service(entity_type)
    case entity_type.to_s.downcase
    when "organe"
      SaumonNet::BodyImportService.new
    when "pays"
      SaumonNet::CountryImportService.new
    else
      raise ArgumentError, "Unknown entity type: #{entity_type}"
    end
  end

  def parse_since_date(since_date)
    case since_date
    when String
      DateTime.parse(since_date)
    when Date, DateTime, Time
      since_date
    else
      raise ArgumentError, "Invalid since_date format: #{since_date}"
    end
    rescue Date::Error
      raise ArgumentError, "Invalid since_date format: #{since_date}"
  end

  def track_import_metrics(entity_type, stats)
    if defined?(NewRelic::Agent)
      NewRelic::Agent.record_metric("Custom/SaumonNet/Import/#{entity_type}/Processed", stats.processed)
      NewRelic::Agent.record_metric("Custom/SaumonNet/Import/#{entity_type}/Created", stats.created)
      NewRelic::Agent.record_metric("Custom/SaumonNet/Import/#{entity_type}/Updated", stats.updated)
      NewRelic::Agent.record_metric("Custom/SaumonNet/Import/#{entity_type}/Failed", stats.failed)
      NewRelic::Agent.record_metric("Custom/SaumonNet/Import/#{entity_type}/SuccessRate", stats.success_rate)
    end
  end

  def stats_summary(stats)
    {
      processed: stats.processed,
      created: stats.created,
      updated: stats.updated,
      skipped: stats.skipped,
      failed: stats.failed,
      success_rate: stats.success_rate
    }
  end
end
