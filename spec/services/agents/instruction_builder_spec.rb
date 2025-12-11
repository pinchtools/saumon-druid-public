RSpec.describe Agents::InstructionBuilder do
  let(:yaml_data) do
    {
      "role" => "Test role",
      "directives" => "Test directives",
      "context_format" => '[{"key": "test"}]'
    }
  end

  describe '#to_s' do
    it 'combines role, directives, and context_format' do
      builder = described_class.new(yaml_data)
      result = builder.to_s

      expect(result).to include("Test role")
      expect(result).to include("Test directives")
      expect(result).to include("CONTEXT_FORMAT")
    end

    it 'handles missing context_format' do
      yaml_without_context = yaml_data.except("context_format")
      builder = described_class.new(yaml_without_context)
      result = builder.to_s

      expect(result).to include("Test role")
      expect(result).not_to include("CONTEXT FORMAT")
    end
  end
end
