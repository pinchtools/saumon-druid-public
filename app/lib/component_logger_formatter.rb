class ComponentLoggerFormatter < Logger::Formatter
  def call(severity, timestamp, progname, msg)
    if component_log_message?(msg)
      format_component_message(severity, timestamp, msg)
    else
      format_default_message(severity, timestamp, progname, msg)
    end
  end

  private

  def component_log_message?(msg)
    msg.is_a?(Hash) && (msg.key?(:session_id) || msg.key?(:component) || msg.key?(:structured))
  end

  def format_component_message(severity, timestamp, msg)
    # Start with timestamp and severity
    parts = ["#{timestamp.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}]"]
    
    # Add component if specified
    if msg[:component]
      parts << "[#{msg[:component]}]"
    end
    
    # Add main message
    if msg[:message]
      parts << msg[:message]
    end
    
    # Add additional context as key=value pairs
    context_parts = []
    msg.except(:message, :component).each do |key, value|
      context_parts << "#{key}=#{value}"
    end
    
    if context_parts.any?
      parts << "| #{context_parts.join(' ')}"
    end
    
    "#{parts.join(' ')}\n"
  end

  def format_default_message(severity, timestamp, progname, msg)
    "#{timestamp.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{progname}: #{msg}\n"
  end
end