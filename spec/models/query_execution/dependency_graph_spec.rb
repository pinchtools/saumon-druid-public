# frozen_string_literal: true

require "rails_helper"

RSpec.describe QueryExecution::DependencyGraph do
  describe "#execution_levels" do
    subject(:graph) { described_class.new(steps) }

    let(:levels) { graph.execution_levels }

    context "with independent steps" do
      let(:steps) do
        [
          { "id" => "a" },
          { "id" => "b" },
          { "id" => "c" }
        ]
      end

      it "groups all steps in the first level" do
        expect(levels.length).to eq(1)
        expect(levels[0].map { |s| s["id"] }).to contain_exactly("a", "b", "c")
      end
    end

    context "with simple dependencies" do
      let(:steps) do
        [
          { "id" => "a", "depends_on" => [] },
          { "id" => "b", "depends_on" => [] },
          { "id" => "c", "depends_on" => [ "a", "b" ] }
        ]
      end

      it "groups independent steps together and dependent steps separately" do
        expect(levels.length).to eq(2)
        expect(levels[0].map { |s| s["id"] }).to contain_exactly("a", "b")
        expect(levels[1].map { |s| s["id"] }).to eq([ "c" ])
      end
    end

    context "with complex dependency chains" do
      let(:steps) do
        [
          { "id" => "a", "depends_on" => [] },
          { "id" => "b", "depends_on" => [ "a" ] },
          { "id" => "c", "depends_on" => [ "a" ] },
          { "id" => "d", "depends_on" => [ "b", "c" ] }
        ]
      end

      it "creates multiple levels based on dependencies" do
        expect(levels.length).to eq(3)
        expect(levels[0].map { |s| s["id"] }).to eq([ "a" ])
        expect(levels[1].map { |s| s["id"] }).to contain_exactly("b", "c")
        expect(levels[2].map { |s| s["id"] }).to eq([ "d" ])
      end
    end

    context "with linear chain" do
      let(:steps) do
        [
          { "id" => "a" },
          { "id" => "b", "depends_on" => [ "a" ] },
          { "id" => "c", "depends_on" => [ "b" ] },
          { "id" => "d", "depends_on" => [ "c" ] }
        ]
      end

      it "creates one level per step" do
        expect(levels.length).to eq(4)
        expect(levels[0].map { |s| s["id"] }).to eq([ "a" ])
        expect(levels[1].map { |s| s["id"] }).to eq([ "b" ])
        expect(levels[2].map { |s| s["id"] }).to eq([ "c" ])
        expect(levels[3].map { |s| s["id"] }).to eq([ "d" ])
      end
    end

    context "with multiple independent chains" do
      let(:steps) do
        [
          { "id" => "a1" },
          { "id" => "a2", "depends_on" => [ "a1" ] },
          { "id" => "b1" },
          { "id" => "b2", "depends_on" => [ "b1" ] }
        ]
      end

      it "executes independent chains in parallel" do
        expect(levels.length).to eq(2)
        expect(levels[0].map { |s| s["id"] }).to contain_exactly("a1", "b1")
        expect(levels[1].map { |s| s["id"] }).to contain_exactly("a2", "b2")
      end
    end

    context "with cyclic dependencies" do
      let(:steps) do
        [
          { "id" => "a", "depends_on" => [ "b" ] },
          { "id" => "b", "depends_on" => [ "a" ] }
        ]
      end

      it "raises CyclicDependencyError for simple cycle" do
        expect { levels }.to raise_error(
          QueryExecution::DependencyGraph::CyclicDependencyError,
          /Cyclic dependency detected/
        )
      end

      context "with complex cycle" do
        let(:steps) do
          [
            { "id" => "a", "depends_on" => [ "b" ] },
            { "id" => "b", "depends_on" => [ "c" ] },
            { "id" => "c", "depends_on" => [ "a" ] }
          ]
        end

        it "raises CyclicDependencyError" do
          expect { levels }.to raise_error(
            QueryExecution::DependencyGraph::CyclicDependencyError,
            /Cyclic dependency detected/
          )
        end
      end

      context "with problematic step IDs" do
        let(:steps) do
          [
            { "id" => "step_a", "depends_on" => [ "step_b" ] },
            { "id" => "step_b", "depends_on" => [ "step_a" ] }
          ]
        end

        it "includes problematic step IDs in error message" do
          expect { levels }.to raise_error do |error|
            expect(error).to be_a(QueryExecution::DependencyGraph::CyclicDependencyError)
            expect(error.message).to include("step_a")
            expect(error.message).to include("step_b")
          end
        end
      end
    end

    context "with self-referencing dependency" do
      let(:steps) do
        [
          { "id" => "a", "depends_on" => [ "a" ] }
        ]
      end

      it "raises CyclicDependencyError" do
        expect { levels }.to raise_error(
          QueryExecution::DependencyGraph::CyclicDependencyError
        )
      end
    end

    context "with missing dependency references" do
      let(:steps) do
        [
          { "id" => "a" },
          { "id" => "b", "depends_on" => [ "nonexistent" ] }
        ]
      end

      it "raises error for missing dependencies" do
        # Step 'b' depends on nonexistent step, so it will never be ready to execute
        # This is detected as a cyclic dependency since step 'b' can never reach in_degree of 0
        expect { levels }.to raise_error(
          QueryExecution::DependencyGraph::CyclicDependencyError,
          /Cyclic dependency detected in steps: b/
        )
      end
    end
  end
end
