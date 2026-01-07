# frozen_string_literal: true

class Conversation
  module Response
    # Immutable result of a stage execution.
    class StageResult
      STATUS_SUCCESS = :success
      STATUS_FAILED = :failed
      STATUS_SKIPPED = :skipped

      attr_reader :stage_name, :status, :data, :error, :skip_reason, :execution_id

      def initialize(stage_name:, status:, data: nil, error: nil, skip_reason: nil, execution_id: nil, halted: false)
        @stage_name = stage_name
        @status = status
        @data = data
        @error = error
        @skip_reason = skip_reason
        @execution_id = execution_id
        @halted = halted
        freeze
      end

      def success?
        status == STATUS_SUCCESS
      end

      def failed?
        status == STATUS_FAILED
      end

      def skipped?
        status == STATUS_SKIPPED
      end

      def halted?
        @halted
      end

      class << self
        def success(stage_name, data, execution_id: nil)
          new(stage_name: stage_name, status: STATUS_SUCCESS, data: data, execution_id: execution_id)
        end

        def failed(stage_name, error, execution_id: nil, halted: false)
          new(stage_name: stage_name, status: STATUS_FAILED, error: error, execution_id: execution_id, halted: halted)
        end

        def skipped(stage_name, reason)
          new(stage_name: stage_name, status: STATUS_SKIPPED, skip_reason: reason)
        end
      end
    end
  end
end
