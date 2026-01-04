# frozen_string_literal: true

module QueryExecution
  # Builds and analyzes the dependency graph for query execution steps
  # Uses topological sort (Kahn's algorithm) to determine execution order
  class DependencyGraph
    class CyclicDependencyError < StandardError; end

    def initialize(steps)
      @steps = steps
      @graph = {}
      @in_degree = {}
      @dependents = Hash.new { |h, k| h[k] = [] }
      build_graph
    end

    # Returns steps grouped by execution levels (topological sort)
    # Steps in the same level can be executed in parallel
    def execution_levels
      levels = []
      remaining = @in_degree.dup

      while has_pending_steps?(remaining)
        ready_steps = find_ready_steps(remaining)
        validate_no_cycles!(ready_steps, remaining)

        levels << steps_for_ids(ready_steps)
        mark_as_processed(ready_steps, remaining)
      end

      levels
    end

    private

    # Builds the dependency graph from steps
    def build_graph
      @steps.each do |step|
        step_id = step["id"]
        dependencies = step["depends_on"] || []

        @graph[step_id] = step
        @in_degree[step_id] = dependencies.size
        register_dependents(step_id, dependencies)
      end
    end

    # Registers reverse dependencies (which steps depend on this step)
    def register_dependents(step_id, dependencies)
      dependencies.each do |dep_id|
        @dependents[dep_id] << step_id
      end
    end

    # Checks if there are still steps to process
    def has_pending_steps?(remaining)
      remaining.any? { |_, degree| degree >= 0 }
    end

    # Finds steps that are ready to execute (all dependencies satisfied)
    def find_ready_steps(remaining)
      remaining.select { |_, degree| degree == 0 }.keys
    end

    # Validates that there are no cyclic dependencies
    def validate_no_cycles!(ready_steps, remaining)
      return unless ready_steps.empty?

      unprocessed = remaining.select { |_, degree| degree > 0 }.keys
      raise CyclicDependencyError, "Cyclic dependency detected in steps: #{unprocessed.join(', ')}"
    end

    # Converts step IDs to step objects
    def steps_for_ids(step_ids)
      step_ids.map { |id| @graph[id] }
    end

    # Marks steps as processed and updates dependents
    def mark_as_processed(ready_steps, remaining)
      ready_steps.each do |step_id|
        remaining[step_id] = -1
        decrement_dependents(step_id, remaining)
      end
    end

    # Decrements in-degree for all steps that depend on this step
    def decrement_dependents(step_id, remaining)
      @dependents[step_id].each do |dependent_id|
        remaining[dependent_id] -= 1 if remaining[dependent_id] > 0
      end
    end
  end
end
