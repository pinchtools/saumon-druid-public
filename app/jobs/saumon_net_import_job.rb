class SaumonNetImportJob < ApplicationJob
  include ServiceEventable

  queue_as :default

  discard_on(SaumonNet::AuthenticationError) { |job, error| notify_discarded_job(job, error) }
  discard_on(SaumonNet::ConfigurationError) { |job, error| notify_discarded_job(job, error) }

  def perform(entity_type, since_date = nil)
    @session_id = SecureRandom.uuid
    Current.job_id = job_id

    import_service = build_import_service(entity_type)

    if since_date.present?
      parsed_date = parse_since_date(since_date)
      stats = import_service.import_since(parsed_date)
    else
      stats = import_service.import_all
    end

    track_event(:job_completed, category: "system", payload: {
      job_class: self.class.name,
      entity_type: entity_type,
      since_date: since_date,
      **stats_summary(stats)
    })
  rescue => e
    track_event(:job_failed, category: "system", severity: :error, payload: {
      job_class: self.class.name,
      entity_type: entity_type,
      since_date: since_date,
      error: e.message,
      backtrace: e.backtrace&.first(10)
    })

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
    when "acteur"
      SaumonNet::StakeholderImportService.new
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
