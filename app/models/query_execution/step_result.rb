# frozen_string_literal: true

module QueryExecution
  class StepResult
    STATUSES = %i[success failed skipped].freeze

    attr_reader :step_id, :status, :data, :error_message_fr, :error_details, :target_model

    def initialize(step_id:, status:, data: nil, error_message_fr: nil, error_details: nil, target_model: nil)
      raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)

      @step_id = step_id
      @status = status
      @data = data
      @error_message_fr = error_message_fr
      @error_details = error_details
      @target_model = target_model
      freeze
    end

    def success?
      status == :success
    end

    def failed?
      status == :failed
    end

    def skipped?
      status == :skipped
    end

    def to_h
      {
        step_id: step_id,
        status: status,
        data: data,
        error_message_fr: error_message_fr,
        error_details: error_details,
        target_model: target_model
      }.compact
    end

    class << self
      def success(step_id:, data:, target_model: nil)
        new(step_id: step_id, status: :success, data: data, target_model: target_model)
      end

      def failed(step_id:, error_message_fr:, error_details: nil)
        new(
          step_id: step_id,
          status: :failed,
          error_message_fr: error_message_fr,
          error_details: error_details
        )
      end

      def skipped(step_id:, reason: nil)
        new(
          step_id: step_id,
          status: :skipped,
          error_message_fr: reason || FrenchErrors.for(:dependency_failed)
        )
      end
    end
  end
end
