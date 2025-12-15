class Event::Observer
  attr_reader :event

  def initialize(event)
    @event = event
  end

  def observe
    log_event
    enqueue_metrics_job
    enqueue_error_reporter_job if event.severity == "error"
  end

  private

  def log_event
    Event::Logger.new(event).log
  end

  def enqueue_metrics_job
    Event::MetricsJob.perform_later(event.id)
  end

  def enqueue_error_reporter_job
    Event::ErrorReporterJob.perform_later(event.id)
  end
end
