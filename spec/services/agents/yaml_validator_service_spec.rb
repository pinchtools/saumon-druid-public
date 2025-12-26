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

    context 'with tools' do
      context 'when tools is a valid array' do
        let(:yaml_with_tools) do
          valid_yaml.deep_merge("agent" => { "tools" => [ "PositionCatalog", "AnotherTool" ] })
        end

        it 'accepts valid tools array' do
          validator = described_class.new(yaml_with_tools)
          expect { validator.valid_params }.not_to raise_error
        end

        it 'includes tools in permitted params' do
          validator = described_class.new(yaml_with_tools)
          params = validator.valid_params

          expect(params["tools"]).to eq([ "PositionCatalog", "AnotherTool" ])
        end
      end

      context 'when tools is invalid' do
        let(:yaml_with_invalid_tools) do
          valid_yaml.deep_merge("agent" => { "tools" => "not_an_array" })
        end

        it 'raises ArgumentError for invalid tools' do
          validator = described_class.new(yaml_with_invalid_tools)
          expect { validator.valid_params }.to raise_error(ArgumentError, /tools must be an array/)
        end
      end

      context 'when tools is an empty array' do
        let(:yaml_with_empty_tools) do
          valid_yaml.deep_merge("agent" => { "tools" => [] })
        end

        it 'raises ArgumentError for empty tools array' do
          validator = described_class.new(yaml_with_empty_tools)
          expect { validator.valid_params }.to raise_error(ArgumentError, /tools array cannot be empty/)
        end
      end
    end
  end
end
