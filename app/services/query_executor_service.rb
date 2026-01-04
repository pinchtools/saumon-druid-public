# frozen_string_literal: true

# Orchestrates the execution of a query plan by managing step dependencies
# and executing steps in the correct order (respecting the dependency graph)
class QueryExecutorService
  include ServiceEventable

  EXECUTION_TIMEOUT = 30

  class ExecutionError < StandardError; end
  class TimeoutError < ExecutionError; end

  def initialize(question:, query_plan:, trace_id: nil)
    @question = question
    @query_plan = query_plan.with_indifferent_access
    @trace_id = trace_id
    @start_time = nil
  end

  def execute
    @start_time = Time.current
    track_execution_started

    validate_plan!

    context = QueryExecution::ExecutionContext.new
    execution_levels = build_execution_levels

    execute_all_levels(execution_levels, context)
    result = build_result(context)
    track_execution_completed(context)
    result
  rescue Concurrent::TimeoutError
    track_execution_timeout
    build_timeout_result
  rescue QueryExecution::DependencyGraph::CyclicDependencyError => e
    track_execution_error(e)
    build_error_result(e.message)
  end

  private

  def validate_plan!
    unless @query_plan["steps"].is_a?(Array) && @query_plan["steps"].any?
      raise ExecutionError, "Query plan must contain at least one step"
    end
  end

  def build_execution_levels
    steps = @query_plan["steps"]
    QueryExecution::DependencyGraph.new(steps).execution_levels
  end

  def execute_all_levels(levels, context)
    levels.each do |level_steps|
      break if context.execution_failed?

      execute_level(level_steps, context)
    end
  end

  def execute_level(level_steps, context)
    if level_steps.size == 1
      execute_single_step(level_steps.first, context)
    else
      execute_parallel_steps(level_steps, context)
    end
  end

  def execute_single_step(step, context)
    result = execute_step(step, context)
    context.store_result(result.step_id, result)
  end

  def execute_parallel_steps(steps, context)
    futures = steps.map do |step|
      Concurrent::Promises.future { execute_step(step, context) }
    end

    results = wait_for_futures(futures)
    store_results(results, context)
  end

  def wait_for_futures(futures)
    combined = Concurrent::Promises.zip(*futures)
    combined.value!(EXECUTION_TIMEOUT)
  end

  def store_results(results, context)
    results.each { |result| context.store_result(result.step_id, result) }
  end

  def execute_step(step, context)
    StepExecutorService.new(step, context).execute
  end

  def build_result(context)
    if context.execution_failed?
      build_failure_result(context)
    else
      build_success_result(context)
    end
  end

  def build_success_result(context)
    base_result(true).merge(
      confidence: @query_plan["confidence"],
      results: context.results_data,
      step_count: context.step_ids.size
    )
  end

  def build_failure_result(context)
    failed = context.failed_results
    messages = failed.map(&:error_message_fr).compact

    base_result(false).merge(
      answer: messages.join("\n"),
      failed_steps: failed.map(&:step_id),
      partial_results: context.results_data
    )
  end

  def build_timeout_result
    base_result(false).merge(
      answer: QueryExecution::FrenchErrors.for(:timeout),
      failed_steps: [],
      partial_results: {}
    )
  end

  def build_error_result(message)
    base_result(false).merge(
      answer: message,
      failed_steps: [],
      partial_results: {}
    )
  end

  def base_result(success)
    { success: success, question: @question }
  end

  # Event tracking methods

  def track_execution_started
    track_event("started", payload: {
      question: @question.truncate(200),
      step_count: @query_plan["steps"]&.size,
      confidence: @query_plan["confidence"]
    })
  end

  def track_execution_completed(context)
    track_event("completed", payload: {
      duration_ms: elapsed_time_ms,
      step_count: context.step_ids.size,
      success_count: context.successful_results.size,
      failed_count: context.failed_results.size
    })
  end

  def track_execution_timeout
    track_event("timeout", severity: :error, payload: {
      duration_ms: elapsed_time_ms,
      timeout_limit: EXECUTION_TIMEOUT
    })
  end

  def track_execution_error(exception)
    track_event("error", severity: :error, payload: {
      duration_ms: elapsed_time_ms,
      error_class: exception.class.name,
      error_message: exception.message.truncate(500)
    })
  end

  def elapsed_time_ms
    return 0 unless @start_time

    ((Time.current - @start_time) * 1000).round
  end

  def service_event_category
    "query_executor"
  end
end
