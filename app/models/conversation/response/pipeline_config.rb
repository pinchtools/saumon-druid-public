# frozen_string_literal: true

class Conversation
  module Response
    # Defines the agent pipeline with conditional logic.
    # Each stage can have conditions and failure handling rules.
    class PipelineConfig
      Stage = Data.define(:name, :agent_class, :service_class, :optional, :on_fail, :conditions) do
        def agent?
          agent_class.present?
        end

        def service?
          service_class.present?
        end
      end

      PIPELINE = [
        Stage.new(
          name: "safety_check",
          agent_class: "Agent::SafetyAgent",
          service_class: nil,
          optional: true,
          on_fail: :halt,
          conditions: nil
        ),
        Stage.new(
          name: "query_rewriter",
          agent_class: "Agent::QueryRewriter",
          service_class: nil,
          optional: true,
          on_fail: :continue,
          conditions: nil
        ),
        Stage.new(
          name: "query_planner",
          agent_class: "Agent::QueryPlannerV2",
          service_class: nil,
          optional: false,
          on_fail: :halt,
          conditions: nil
        ),
        Stage.new(
          name: "query_executor",
          agent_class: nil,
          service_class: "QueryExecutorService",
          optional: false,
          on_fail: :halt,
          conditions: ->(ctx) { ctx.get_result("query_planner").present? }
        ),
        Stage.new(
          name: "answer_composer",
          agent_class: "Agent::AnswerComposer",
          service_class: nil,
          optional: false,
          on_fail: :halt,
          conditions: ->(ctx) { ctx.get_result("query_executor").present? }
        )
      ].freeze

      class << self
        def stages
          PIPELINE
        end

        def find_stage(name)
          PIPELINE.find { |s| s.name == name.to_s }
        end

        def agent_stages
          PIPELINE.select(&:agent?)
        end

        def service_stages
          PIPELINE.select(&:service?)
        end
      end
    end
  end
end
