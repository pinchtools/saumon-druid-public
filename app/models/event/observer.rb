class Event::Observer
  attr_reader :event

  def initialize(event)
    @event = event
  end

  def observe
    log_event
    record_metrics
    capture_error if event.severity == "error"
  end

  private

  def log_event
    Event::Logger.new(event).log
  end

  def record_metrics
    Event::Metrics.new(event).record
  end

  def capture_error
    Event::ErrorReporter.new(event).report
  end
end
