require_relative '../../app/lib/structured_logger_formatter'

# Configure structured logging for the application
Rails.application.configure do
  # Use structured logger formatter for consistent JSON logging
  config.log_formatter = StructuredLoggerFormatter.new
end
