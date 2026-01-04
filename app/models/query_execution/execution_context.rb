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
      @results[step_id]
    end

    def all_results
      @results.to_h
    end

    def results_data
      @results.transform_values { |result| result.success? ? result.data : nil }
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
  end
end
