# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Event::PayloadTruncator do
  describe '#truncate' do
    context 'with string values' do
      it 'preserves short strings' do
        payload = { message: "Hello world" }
        result = described_class.new(payload).truncate

        expect(result[:message]).to eq("Hello world")
      end

      it 'truncates long strings' do
        payload = { message: "a" * 1500 }
        result = described_class.new(payload).truncate

        expect(result[:message]).to start_with("a" * 1000)
        expect(result[:message]).to include("[truncated 500 chars]")
        expect(result[:message].length).to be < 1500
      end
    end

    context 'with array values' do
      it 'preserves small arrays' do
        payload = { items: [ 1, 2, 3 ] }
        result = described_class.new(payload).truncate

        expect(result[:items]).to eq([ 1, 2, 3 ])
      end

      it 'truncates large arrays' do
        payload = { items: (1..20).to_a }
        result = described_class.new(payload).truncate

        expect(result[:items].size).to eq(11) # 10 items + truncation message
        expect(result[:items].first(10)).to eq((1..10).to_a)
        expect(result[:items].last).to include("10 more items")
      end
    end

    context 'with nested hashes' do
      it 'preserves shallow nesting' do
        payload = { user: { name: "John", age: 30 } }
        result = described_class.new(payload).truncate

        expect(result[:user][:name]).to eq("John")
        expect(result[:user][:age]).to eq(30)
      end

      it 'limits nesting depth' do
        payload = {
          level1: {
            level2: {
              level3: {
                level4: "too deep"
              }
            }
          }
        }
        result = described_class.new(payload).truncate

        expect(result[:level1][:level2][:level3]).to eq("[max depth exceeded]")
      end
    end

    context 'with sensitive fields' do
      it 'filters out password fields using Rails filter_parameters' do
        # Rails ActiveSupport::ParameterFilter masks values with [FILTERED]
        payload = { username: "john", password: "secret123" }
        result = described_class.new(payload).truncate

        expect(result[:username]).to eq("john")
        # After filtering, password should be marked as [FILTERED] rather than removed
        expect(result[:password]).to eq("[FILTERED]")
      end

      it 'uses Rails filter_parameters configuration for multiple sensitive fields' do
        # Rails masks sensitive fields with [FILTERED]
        # Note: email might also be filtered depending on Rails config
        payload = {
          username: "john_doe",
          password: "secret",
          password_confirmation: "secret"
        }
        result = described_class.new(payload).truncate

        expect(result[:username]).to be_present # Username not filtered
        expect(result[:password]).to eq("[FILTERED]")
        expect(result[:password_confirmation]).to eq("[FILTERED]")
      end
    end

    context 'with large payloads' do
      it 'applies aggressive truncation when over size limit' do
        # Create a payload larger than 10KB
        large_string = "x" * 20_000
        payload = {
          field1: large_string,
          field2: large_string,
          field3: large_string
        }

        result = described_class.new(payload).truncate

        # Should be significantly reduced
        json_size = result.to_json.bytesize
        expect(json_size).to be < 10_240
      end
    end

    context 'with mixed data types' do
      it 'handles complex nested structures' do
        payload = {
          string: "test",
          number: 123,
          boolean: true,
          nil_value: nil,
          array: [ 1, 2, 3 ],
          hash: { key: "value" }
        }
        result = described_class.new(payload).truncate

        expect(result[:string]).to eq("test")
        expect(result[:number]).to eq(123)
        expect(result[:boolean]).to eq(true)
        expect(result[:nil_value]).to be_nil
        expect(result[:array]).to eq([ 1, 2, 3 ])
        expect(result[:hash][:key]).to eq("value")
      end
    end

    context 'with non-hash input' do
      it 'returns empty hash for non-hash input' do
        result = described_class.new("not a hash").truncate

        expect(result).to eq({})
      end

      it 'returns empty hash for nil input' do
        result = described_class.new(nil).truncate

        expect(result).to eq({})
      end
    end
  end
end
