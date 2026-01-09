# frozen_string_literal: true

# Provides debugging helpers and payload conventions for Event model
module Event::Debuggable
  extend ActiveSupport::Concern

  # Payload Conventions:
  # ====================
  # All conversation-related events should include in payload:
  # - message_id: The message being processed
  # - conversation_id: The conversation context
  # - trace_id: Optional trace identifier for correlation
  #
  # Service/Agent events should include:
  # - input: The input data (may be truncated for logging)
  # - output: The output/result (may be truncated for logging)
  # - duration_ms: Execution time in milliseconds
  #
  # Error events should include:
  # - error_class: Exception class name
  # - error_message: Exception message (truncated to 500 chars)
  # - backtrace: First 10 lines of backtrace (optional)

  included do
    scope :for_conversation, ->(conversation_id) {
      where("payload->>'conversation_id' = ?", conversation_id.to_s)
    }
    scope :for_message, ->(message_id) {
      where("payload->>'message_id' = ?", message_id.to_s)
    }
    scope :with_trace, ->(trace_id) {
      where("payload->>'trace_id' = ?", trace_id.to_s)
    }

    scope :debug_conversation, ->(conversation_id, limit = 100) {
      for_conversation(conversation_id).recent.limit(limit)
    }
    scope :debug_message, ->(message_id, limit = 100) {
      for_message(message_id).recent.limit(limit)
    }
    scope :debug_trace, ->(trace_id, limit = 100) {
      with_trace(trace_id).recent.limit(limit)
    }
  end

  def conversation_id
    payload["conversation_id"]
  end

  def message_id
    payload["message_id"]
  end

  def trace_id
    payload["trace_id"]
  end

  class_methods do
    # Pretty print events for debugging in console
    # Shows timestamp, category.action, severity, and key payload fields
    #
    # @param events [ActiveRecord::Relation] Events to print
    # @param output [IO] Output stream (defaults to $stdout)
    #
    # Example:
    #   Event.debug_message("123").then { |e| Event.pretty_print(e) }
    def pretty_print(events, output: $stdout)
      events.each do |event|
        output.puts format_event(event)
        output.puts "-" * 80
      end
      nil
    end

    private

    def format_event(event)
      lines = []
      lines << "[#{event.created_at.iso8601}] #{event.full_action} (#{event.severity})"
      lines << "  Session: #{event.session_id}" if event.session_id
      lines << "  Job: #{event.job_id}" if event.job_id
      lines << "  Message: #{event.message_id}" if event.message_id
      lines << "  Conversation: #{event.conversation_id}" if event.conversation_id

      if event.payload.present?
        lines << "  Payload:"
        event.payload.each do |key, value|
          next if %w[message_id conversation_id trace_id].include?(key)
          lines << "    #{key}: #{format_value(value)}"
        end
      end

      lines.join("\n")
    end

    def format_value(value)
      case value
      when String
        value.length > 100 ? "#{value[0...100]}..." : value
      when Array
        "[#{value.size} items]"
      when Hash
        "{#{value.keys.join(', ')}}"
      else
        value.inspect
      end
    end
  end
end
