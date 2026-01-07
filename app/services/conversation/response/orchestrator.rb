# frozen_string_literal: true

class Conversation
  module Response
    class Orchestrator
      include ServiceEventable

      class OrchestratorError < StandardError; end
      class PipelineHaltedError < OrchestratorError; end

      EVENT_STARTED = "started"
      EVENT_COMPLETED = "completed"
      EVENT_HALTED = "halted"
      EVENT_ERROR = "error"

      def initialize(conversation:, message:)
        @conversation = conversation
        @message = message
        @start_time = nil
      end

      def execute
        @start_time = Time.current
        prepare_execution
        context = build_context
        run_pipeline(context)

        if context.halted?
          finalize_halted(context)
        else
          finalize_success(context)
        end
      rescue PipelineHaltedError
        finalize_halted(context)
      rescue StandardError => e
        finalize_error(e)
      end

      private

      attr_reader :conversation, :message

      def prepare_execution
        message.mark_processing!
        Current.session_id = conversation.session_id
        Current.request_id ||= SecureRandom.uuid
        track_started
      end

      def build_context
        question = conversation.last_user_message&.content
        raise OrchestratorError, "No user message found" unless question

        Context.new(conversation: conversation, message: message, question: question)
      end

      def run_pipeline(context)
        PipelineConfig.stages.each do |stage|
          break if context.halted? || context.skip_remaining?

          result = run_stage(stage, context)
          handle_stage_result(stage, result)
        end
      end

      def run_stage(stage, context)
        track_stage_started(stage.name)
        result = StageRunner.new(stage: stage, context: context).run
        track_stage_result(stage.name, result)
        result
      end

      def handle_stage_result(stage, result)
        raise PipelineHaltedError, halt_reason(result) if result.halted?
      end

      def halt_reason(result)
        result.error&.message || "Pipeline halted at #{result.stage_name}"
      end

      def finalize_success(context)
        answer = extract_answer(context)

        if answer.present?
          message.complete!(answer)
          conversation.complete! if conversation.active?
        else
          message.fail!("Unable to generate response")
        end

        track_completed(context)
        build_success_response(context)
      end

      def extract_answer(context)
        result = context.get_result("answer_composer")
        result["answer"] || result[:answer] if result
      end

      def finalize_halted(context)
        reason = context&.get_metadata("halt_reason") || "Pipeline halted"
        message.fail!(reason)
        conversation.fail!(reason: reason) if conversation.active?
        track_halted(reason)
        build_error_response(reason)
      end

      def finalize_error(error)
        log_error(error)
        message.fail!(error.message)
        conversation.fail!(reason: error.message)
        track_error(error)
        build_error_response(error.message)
      end

      def log_error(error)
        Rails.logger.error("Orchestration error: #{error.message}\n#{error.backtrace.first(10).join("\n")}")
      end

      def build_success_response(context)
        { success: true, message_id: message.id, content: message.content,
          metadata: context.metadata, duration_ms: elapsed_time_ms }
      end

      def build_error_response(error_message)
        { success: false, message_id: message.id, error: error_message, duration_ms: elapsed_time_ms }
      end

      def elapsed_time_ms
        return 0 unless @start_time

        ((Time.current - @start_time) * 1000).round
      end

      def track_started
        track_event(EVENT_STARTED, payload: {
          conversation_id: conversation.id, message_id: message.id,
          question: conversation.last_user_message&.content&.truncate(200)
        })
      end

      def track_completed(context)
        track_event(EVENT_COMPLETED, payload: {
          conversation_id: conversation.id, message_id: message.id,
          duration_ms: elapsed_time_ms, stages_executed: context.results.keys
        })
      end

      def track_halted(reason)
        track_event(EVENT_HALTED, severity: :warn, payload: {
          conversation_id: conversation.id, message_id: message.id,
          duration_ms: elapsed_time_ms, reason: reason.to_s.truncate(500)
        })
      end

      def track_error(error)
        track_event(EVENT_ERROR, severity: :error, payload: {
          conversation_id: conversation.id, message_id: message.id,
          duration_ms: elapsed_time_ms, error_class: error.class.name,
          error_message: error.message.truncate(500)
        })
      end

      def track_stage_started(stage_name)
        track_event("stage.#{stage_name}.started", payload: {
          conversation_id: conversation.id, message_id: message.id
        })
      end

      def track_stage_result(stage_name, result)
        action = result.skipped? ? "skipped" : "completed"
        payload = { conversation_id: conversation.id, message_id: message.id }
        payload[:reason] = result.skip_reason if result.skipped?

        track_event("stage.#{stage_name}.#{action}", payload: payload)
      end

      def service_event_category
        "orchestrator"
      end
    end
  end
end
