require 'rails_helper'

RSpec.describe Agents::YamlValidatorService do
  let(:valid_yaml) do
    {
      "agent" => {
        "name" => "test_agent",
        "description" => "A test agent",
        "role" => "Test role",
        "directives" => "Test directives",
        "models" => [ "gpt5-turbo" ]
      }
    }
  end

  describe '#valid_params ' do
    context 'with valid YAML' do
      it 'returns permitted parameters' do
        validator = described_class.new(valid_yaml)
        params = validator.valid_params

        expect(params["name"]).to eq("test_agent")
        expect(params["description"]).to eq("A test agent")
      end
    end

    context 'with invalid YAML structure' do
      it 'raises ArgumentError for missing agent key' do
        validator = described_class.new({})
        expect { validator.valid_params }.to raise_error(ArgumentError, /Missing 'agent' key/)
      end

      it 'raises ArgumentError for missing required fields' do
        invalid_yaml = { "agent" => { "name" => "test" } }
        validator = described_class.new(invalid_yaml)
        expect { validator.valid_params }.to raise_error(ArgumentError, /Missing required field/)
      end
    end

    context 'with invalid context_format' do
      let(:yaml_with_invalid_json) do
        valid_yaml.deep_merge("agent" => { "context_format" => "invalid json" })
      end

      it 'raises ArgumentError for invalid JSON' do
        validator = described_class.new(yaml_with_invalid_json)
        expect { validator.valid_params }.to raise_error(ArgumentError, /Invalid context_format/)
      end
    end

    context 'with valid context_format' do
      let(:yaml_with_valid_json) do
        valid_yaml.deep_merge("agent" => { "context_format" => '[{"key": "test"}]' })
      end

      it 'accepts valid JSON array' do
        validator = described_class.new(yaml_with_valid_json)
        expect { validator.valid_params }.not_to raise_error
      end
    end
  end
end
