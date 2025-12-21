require "rails_helper"

RSpec.describe JsonRepairable do
  let(:test_class) do
    Class.new do
      include JsonRepairable
    end
  end

  let(:repairer) { test_class.new }

  describe "#repair_json" do
    context "with valid JSON" do
      it "parses valid JSON object" do
        json = '{"name": "test", "value": 123}'

        expect(repairer.repair_json(json)).to eq("name" => "test", "value" => 123)
      end

      it "parses valid JSON array" do
        json = '[1, 2, 3]'

        expect(repairer.repair_json(json)).to eq([ 1, 2, 3 ])
      end

      it "returns empty hash for blank input" do
        expect(repairer.repair_json(nil)).to eq({})
        expect(repairer.repair_json("")).to eq({})
        expect(repairer.repair_json("   ")).to eq({})
      end
    end

    context "with markdown code blocks" do
      it "extracts JSON from ```json blocks" do
        json = "```json\n{\"key\": \"value\"}\n```"

        expect(repairer.repair_json(json)).to eq("key" => "value")
      end

      it "extracts JSON from plain ``` blocks" do
        json = "```\n{\"key\": \"value\"}\n```"

        expect(repairer.repair_json(json)).to eq("key" => "value")
      end

      it "handles markdown with leading text" do
        json = "Here is the result:\n```json\n{\"key\": \"value\"}\n```"

        expect(repairer.repair_json(json)).to eq("key" => "value")
      end
    end

    context "with JSON embedded in text" do
      it "extracts JSON object from surrounding text" do
        json = 'Here is the result: {"key": "value"} Let me explain...'

        expect(repairer.repair_json(json)).to eq("key" => "value")
      end

      it "extracts JSON array from surrounding text" do
        json = 'The array is: [1, 2, 3] as you can see'

        expect(repairer.repair_json(json)).to eq([ 1, 2, 3 ])
      end
    end

    context "with Python-style values" do
      it "converts True to true" do
        json = '{"active": True}'

        expect(repairer.repair_json(json)).to eq("active" => true)
      end

      it "converts False to false" do
        json = '{"active": False}'

        expect(repairer.repair_json(json)).to eq("active" => false)
      end

      it "converts None to null" do
        json = '{"value": None}'

        expect(repairer.repair_json(json)).to eq("value" => nil)
      end

      it "converts NaN to null" do
        json = '{"value": NaN}'

        expect(repairer.repair_json(json)).to eq("value" => nil)
      end

      it "converts Infinity to null" do
        json = '{"value": Infinity}'

        expect(repairer.repair_json(json)).to eq("value" => nil)
      end

      it "converts -Infinity to null" do
        json = '{"value": -Infinity}'

        expect(repairer.repair_json(json)).to eq("value" => nil)
      end
    end

    context "with trailing commas" do
      it "removes trailing comma before closing brace" do
        json = '{"key": "value",}'

        expect(repairer.repair_json(json)).to eq("key" => "value")
      end

      it "removes trailing comma before closing bracket" do
        json = '[1, 2, 3,]'

        expect(repairer.repair_json(json)).to eq([ 1, 2, 3 ])
      end

      it "removes trailing comma with whitespace" do
        json = '{"key": "value"  ,  }'

        expect(repairer.repair_json(json)).to eq("key" => "value")
      end
    end

    context "with JavaScript comments" do
      it "removes single-line comments" do
        json = "{\"key\": \"value\" // this is a comment\n}"

        expect(repairer.repair_json(json)).to eq("key" => "value")
      end

      it "removes multi-line comments" do
        json = '{"key": /* comment */ "value"}'

        expect(repairer.repair_json(json)).to eq("key" => "value")
      end
    end

    context "with unquoted keys" do
      it "quotes unquoted keys" do
        json = '{name: "test", value: 123}'

        expect(repairer.repair_json(json)).to eq("name" => "test", "value" => 123)
      end

      it "quotes keys with underscores" do
        json = '{first_name: "John", last_name: "Doe"}'

        expect(repairer.repair_json(json)).to eq("first_name" => "John", "last_name" => "Doe")
      end

      it "handles mixed quoted and unquoted keys" do
        json = '{"name": "test", value: 123}'

        expect(repairer.repair_json(json)).to eq("name" => "test", "value" => 123)
      end
    end

    context "with single quotes" do
      it "converts single-quoted keys" do
        json = "{'name': 'test'}"

        expect(repairer.repair_json(json)).to eq("name" => "test")
      end

      it "converts single-quoted values" do
        json = "{\"name\": 'test'}"

        expect(repairer.repair_json(json)).to eq("name" => "test")
      end

      it "handles single-quoted array elements" do
        json = "['a', 'b', 'c']"

        expect(repairer.repair_json(json)).to eq(%w[a b c])
      end
    end

    context "with missing commas" do
      it "inserts missing comma between array elements (objects)" do
        json = '[{"a": 1} {"b": 2}]'

        result = repairer.repair_json(json)

        expect(result).to eq([ { "a" => 1 }, { "b" => 2 } ])
      end

      it "inserts missing comma between string values" do
        json = '["a" "b" "c"]'

        expect(repairer.repair_json(json)).to eq(%w[a b c])
      end
    end

    context "with unbalanced braces" do
      it "closes missing brace at end" do
        json = '{"key": "value"'

        expect(repairer.repair_json(json)).to eq("key" => "value")
      end

      it "closes missing bracket at end" do
        json = '[1, 2, 3'

        expect(repairer.repair_json(json)).to eq([ 1, 2, 3 ])
      end

      it "closes nested missing braces" do
        json = '{"outer": {"inner": "value"}'

        expect(repairer.repair_json(json)).to eq("outer" => { "inner" => "value" })
      end
    end

    context "with complex nested structures" do
      it "handles nested objects" do
        json = '{"level1": {"level2": {"level3": "value"}}}'

        expect(repairer.repair_json(json)).to eq(
          "level1" => { "level2" => { "level3" => "value" } }
        )
      end

      it "handles arrays of objects" do
        json = '[{"id": 1}, {"id": 2}]'

        expect(repairer.repair_json(json)).to eq([ { "id" => 1 }, { "id" => 2 } ])
      end

      it "repairs complex LLM output with multiple issues" do
        json = <<~JSON
          ```json
          {
            name: "test",
            active: True,
            items: [1, 2, 3,],
            nested: {
              value: None
            },
          }
          ```
        JSON

        result = repairer.repair_json(json)

        expect(result["name"]).to eq("test")
        expect(result["active"]).to be(true)
        expect(result["items"]).to eq([ 1, 2, 3 ])
        expect(result["nested"]["value"]).to be_nil
      end
    end

    context "with unrepairable JSON" do
      it "raises RepairError for completely invalid input" do
        expect do
          repairer.repair_json("this is not json at all")
        end.to raise_error(JsonRepairable::RepairError, /Unable to repair JSON/)
      end

      it "raises RepairError for malformed structure" do
        expect do
          repairer.repair_json("}{")
        end.to raise_error(JsonRepairable::RepairError)
      end
    end

    context "edge cases" do
      it "handles empty object" do
        expect(repairer.repair_json("{}")).to eq({})
      end

      it "handles empty array" do
        expect(repairer.repair_json("[]")).to eq([])
      end

      it "preserves valid apostrophes in strings" do
        json = '{"message": "It\'s working"}'

        expect(repairer.repair_json(json)).to eq("message" => "It's working")
      end

      it "handles unicode characters" do
        json = '{"name": "François", "city": "Montréal"}'

        expect(repairer.repair_json(json)).to eq("name" => "François", "city" => "Montréal")
      end

      it "handles escaped quotes in strings" do
        json = '{"quote": "He said \\"hello\\""}'

        expect(repairer.repair_json(json)).to eq("quote" => 'He said "hello"')
      end
    end
  end
end
