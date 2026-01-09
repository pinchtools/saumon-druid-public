class Event::ErrorReporter
  attr_reader :event

  def initialize(event)
    @event = event
  end

  def report
    return unless defined?(Sentry)

    Sentry.capture_message(
      "#{event.full_action}: #{error_message}",
      level: :error,
      extra: sentry_extra,
      tags: sentry_tags
    )
  end

  private

  def error_message
    event.payload["error"] || event.payload["message"] || event.action
  end

  def sentry_extra
    base_extra = {
      event_id: event.id,
      eventable: eventable_identifier,
      session_id: event.session_id
    }

    truncated_payload = Event::PayloadTruncator.new(event.payload).truncate

    base_extra.merge(truncated_payload)
  end

  def sentry_tags
    {
      event_category: event.category,
      event_action: event.action
    }
  end

  def eventable_identifier
    return nil unless event.eventable_type
    "#{event.eventable_type}##{event.eventable_id}"
  end
end
