# frozen_string_literal: true

class Conversation
  module Response
    # Thread-safe context passed through the agent pipeline.
    # Similar to QueryExecution::ExecutionContext but for conversations.
    #
    # Results are stored as arrays to support retries and parallel execution:
    #   results["query_planner"] = [
    #     { id: "uuid1", result: {...}, at: Time },
    #     { id: "uuid2", result: {...}, at: Time }
    #   ]
    class Context
      ExecutionEntry = Data.define(:id, :result, :at)

      attr_reader :conversation, :message, :question

      def initialize(conversation:, message:, question:)
        @conversation = conversation
        @message = message
        @question = question
        @results = Concurrent::Hash.new { |h, k| h[k] = Concurrent::Array.new }
        @metadata = Concurrent::Hash.new
        @halted = Concurrent::AtomicBoolean.new(false)
        @skip_remaining = Concurrent::AtomicBoolean.new(false)
      end

      # Store a result for a stage execution
      def store_result(stage_name, result, execution_id: nil)
        entry = ExecutionEntry.new(
          id: execution_id || SecureRandom.uuid,
          result: result,
          at: Time.current
        )
        @results[stage_name.to_s] << entry
        entry
      end

      # Get the most recent result for a stage
      def get_result(stage_name)
        @results[stage_name.to_s].last&.result
      end

      # Get all execution entries for a stage
      def get_executions(stage_name)
        @results[stage_name.to_s].dup
      end

      # Get a specific execution by ID
      def get_execution(stage_name, execution_id)
        @results[stage_name.to_s].find { |e| e.id == execution_id }
      end

      # Get execution count for a stage (useful for retry tracking)
      def execution_count(stage_name)
        @results[stage_name.to_s].size
      end

      # Get all latest results as a hash (for compatibility)
      def results
        @results.each_with_object({}) do |(stage_name, entries), hash|
          hash[stage_name] = entries.last&.result
        end
      end

      # Get full results with all executions
      def all_results
        @results.transform_values(&:dup)
      end

      def set_metadata(key, value)
        @metadata[key.to_s] = value
      end

      def get_metadata(key)
        @metadata[key.to_s]
      end

      def metadata
        @metadata.to_h
      end

      def halt!(reason: nil)
        @halted.make_true
        set_metadata("halt_reason", reason) if reason
      end

      def halted?
        @halted.true?
      end

      def skip_remaining!(reason: nil)
        @skip_remaining.make_true
        set_metadata("skip_reason", reason) if reason
      end

      def skip_remaining?
        @skip_remaining.true?
      end

      def session_id
        @conversation.session_id
      end

      def to_h
        {
          conversation_id: @conversation.id,
          message_id: @message.id,
          question: @question,
          results: results,
          metadata: metadata,
          halted: halted?,
          skip_remaining: skip_remaining?
        }
      end
    end
  end
end
