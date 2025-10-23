class RailsEventLoggerSubscriber
  def initialize(logger = Rails.logger)
    @logger = logger
  end

  def emit(event_hash)
    # Convert Rails event to the format expected by ComponentLoggerFormatter
    log_data = {
      message: event_hash[:name] || "Event",
      component: extract_component_from_event_name(event_hash[:name]),
      structured: true
    }

    # Add all event data except the name (which becomes the message)
    event_hash[:payload].except(:name).each do |key, value|
      log_data[key] = value
    end

    # Extract severity from tags or default to info
    severity = event_hash[:tags]&.dig(:severity) || :info

    # Filter out severity from tags for logging
    filtered_tags = event_hash[:tags]&.except(:severity) || {}
    log_data[:tags] = filtered_tags.map { |k, v| "#{k}=#{v}" }
    log_data[:context] = event_hash[:context]&.map { |k, v| "#{k}=#{v}" } || []

    # Log using the existing formatter with appropriate severity
    @logger.send(severity, log_data)
  end

  private

  def extract_component_from_event_name(event_name)
    return nil unless event_name

    # Extract component from event name like "user.login" -> "user"
    parts = event_name.split(".")
    parts.length > 1 ? parts.first : nil
  end
end
