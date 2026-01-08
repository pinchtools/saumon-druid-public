# frozen_string_literal: true

class Conversation
  module Response
    # Executes a single pipeline stage (agent or service).
    # Handles input building, execution, and result processing.
    class StageRunner
      include ServiceEventable

      attr_reader :stage, :context, :execution_id

      def initialize(stage:, context:, execution_id: nil)
        @stage = stage
        @context = context
        @execution_id = execution_id || SecureRandom.uuid
      end

      def run
        return skip_result(:agent_not_configured) if skip_optional_agent?
        return skip_result(:condition_not_met) if condition_not_met?

        execute_and_store_result
      end

      def attempt_number
        context.execution_count(stage.name) + 1
      end

      private

      def skip_optional_agent?
        return false unless stage.optional && stage.agent?

        agent_name = stage.agent_class.demodulize.underscore
        !Agent.with_name(agent_name).active.exists?
      end

      def condition_not_met?
        stage.conditions && !stage.conditions.call(context)
      end

      def skip_result(reason)
        StageResult.skipped(stage.name, reason)
      end

      def execute_and_store_result
        result = execute_stage
        context.store_result(stage.name, result, execution_id: execution_id)
        process_signals(result)
        StageResult.success(stage.name, result, execution_id: execution_id)
      rescue StandardError => e
        handle_error(e)
      end

      def execute_stage
        if stage.agent?
          execute_agent
        elsif stage.service?
          execute_service
        else
          raise ArgumentError, "Invalid stage configuration: #{stage.name}"
        end
      end

      def execute_agent
        agent_class = stage.agent_class.constantize
        agent = agent_class.new
        agent.call(build_agent_input)
      end

      def execute_service
        case stage.service_class
        when "QueryExecutorService"
          execute_query_executor
        else
          raise ArgumentError, "Unknown service: #{stage.service_class}"
        end
      end

      def execute_query_executor
        query_plan = context.get_result("query_planner")
        QueryExecutorService.new(
          question: context.question,
          query_plan: query_plan,
          trace_id: context.session_id
        ).execute
      end

      def build_agent_input
        base_input = { trace_id: context.session_id, message_id: context.message.id }

        case stage.name
        when "safety_check", "query_rewriter", "query_planner"
          base_input.merge(question: context.question)
        when "answer_composer"
          build_answer_composer_input(base_input)
        else
          base_input.merge(question: context.question)
        end
      end

      def build_answer_composer_input(base_input)
        execution_result = context.get_result("query_executor")
        base_input.merge(
          question: context.question,
          results: extract_results(execution_result),
          confidence: extract_confidence
        )
      end

      def extract_results(execution_result)
        execution_result[:results] || {}
      end

      def extract_confidence
        planner_result = context.get_result("query_planner")
        planner_result&.dig(:confidence)
      end

      def process_signals(result)
        return unless result.is_a?(Hash)

        process_halt_signal(result)
        process_skip_signal(result)
      end

      def process_halt_signal(result)
        return unless result[:halt]

        context.halt!(reason: result[:halt_reason])
      end

      def process_skip_signal(result)
        return unless result[:skip_remaining]

        context.skip_remaining!(reason: result[:skip_reason])
      end

      def handle_error(error)
        case stage.on_fail
        when :halt
          context.halt!(reason: error.message)
          StageResult.failed(stage.name, error, execution_id: execution_id, halted: true)
        when :continue
          context.set_metadata("#{stage.name}_error", error.message)
          StageResult.failed(stage.name, error, execution_id: execution_id, halted: false)
        else
          raise error
        end
      end

      def service_event_category
        "orchestrator"
      end
    end
  end
end
