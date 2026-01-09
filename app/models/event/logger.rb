class Event::Logger
  attr_reader :event

  SEVERITY_MAP = {
    "debug" => :debug,
    "info" => :info,
    "warn" => :warn,
    "error" => :error
  }.freeze

  def initialize(event)
    @event = event
  end

  def log
    Rails.logger.public_send(log_level, formatted_message)
  end

  private

  def log_level
    SEVERITY_MAP[event.severity] || :info
  end

  def formatted_message
    truncated_payload = Event::PayloadTruncator.new(event.payload).truncate

    {
      event: event.full_action,
      severity: event.severity,
      eventable: eventable_identifier,
      session_id: event.session_id,
      request_id: event.request_id,
      job_id: event.job_id,
      **truncated_payload.symbolize_keys
    }
  end

  def eventable_identifier
    return nil unless event.eventable_type
    "#{event.eventable_type}##{event.eventable_id}"
  end
end
