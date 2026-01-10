# frozen_string_literal: true

class Conversation
  module Response
    class ProcessingJob < ApplicationJob
      include ServiceEventable

      queue_as :default

      retry_on RubyLLM::ServiceUnavailableError, wait: :polynomially_longer, attempts: 3
      retry_on RubyLLM::RateLimitError, wait: 30.seconds, attempts: 5

      discard_on RubyLLM::UnauthorizedError
      discard_on RubyLLM::PaymentRequiredError
      discard_on ArgumentError

      def perform(conversation_id, message_id)
        @conversation_id = conversation_id
        @message_id = message_id

        Current.conversation_id = conversation_id
        Current.message_id = message_id

        conversation = Conversation.find(conversation_id)
        message = Message.find(message_id)

        unless message.pending?
          track_event(:job_skipped, payload: base_payload.merge(
            reason: "already_processed",
            current_status: message.status
          ))
          return
        end

        result = Orchestrator.new(
          conversation: conversation,
          message: message
        ).execute

        track_job_result(result)
      rescue ActiveRecord::RecordNotFound => e
        track_job_error(e)
      rescue StandardError => e
        track_job_error(e)
        raise
      end

      private

      def base_payload
        {
          job_class: self.class.name,
          conversation_id: @conversation_id,
          message_id: @message_id
        }
      end

      def track_job_result(result)
        if result[:success]
          track_event(:job_completed, payload: base_payload.merge(
            duration_ms: result[:duration_ms]
          ))
        else
          track_event(:job_failed, severity: :error, payload: base_payload.merge(
            error: result[:error]
          ))
        end
      end

      def track_job_error(error)
        track_event(:job_error, severity: :error, payload: base_payload.merge(
          error_class: error.class.name,
          error_message: error.message.truncate(500),
          backtrace: error.backtrace&.first(5)
        ))
      end

      def service_event_category
        "system"
      end
    end
  end
end
