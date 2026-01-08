# frozen_string_literal: true

module QueryExecution
  class ExecutionContext
    def initialize
      @results = Concurrent::Hash.new
      @failed = Concurrent::AtomicBoolean.new(false)
    end

    def store_result(step_id, result)
      @results[step_id] = result
      @failed.make_true if result.failed?
    end

    def get_result(step_id)
      result = @results[step_id]
      ensure_indifferent_access(result)
    end

    def all_results
      @results.to_h.transform_values { |v| ensure_indifferent_access(v) }
    end

    def results_data
      @results.transform_values do |result|
        data = result.success? ? result.data : nil
        ensure_indifferent_access(data)
      end
    end

    def execution_failed?
      @failed.true?
    end

    def failed_results
      @results.values.select(&:failed?)
    end

    def successful_results
      @results.values.select(&:success?)
    end

    def step_ids
      @results.keys
    end

    def complete?
      @results.values.all? { |r| r.success? || r.failed? || r.skipped? }
    end

    private

    def ensure_indifferent_access(value)
      case value
      when Hash
        value.with_indifferent_access
      when Array
        value.map { |v| ensure_indifferent_access(v) }
      else
        value
      end
    end
  end
end
