class StructuredLoggerFormatter < Logger::Formatter
  def call(severity, timestamp, progname, msg)
    if structured_log_message?(msg)
      format_structured_message(severity, timestamp, msg)
    else
      format_default_message(severity, timestamp, progname, msg)
    end
  end

  private

  def structured_log_message?(msg)
    msg.is_a?(Hash) && (msg.key?(:session_id) || msg.key?(:component) || msg.key?(:structured))
  end

  def format_structured_message(severity, timestamp, msg)
    formatted_msg = {
      timestamp: timestamp.iso8601,
      level: severity
    }

    # Add component if specified
    if msg[:component]
      formatted_msg[:component] = msg[:component]
    end

    # Extract main message
    if msg[:message]
      formatted_msg[:message] = msg[:message]
      formatted_msg.merge!(msg.except(:message))
    else
      formatted_msg.merge!(msg)
    end

    "#{formatted_msg.to_json}\n"
  end

  def format_default_message(severity, timestamp, progname, msg)
    "#{timestamp} [#{severity}] #{progname}: #{msg}\n"
  end
end