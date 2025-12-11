RSpec.describe Agents::ConfigurationResult do
  describe '#success?' do
    it 'always returns true' do
      result = described_class.new(agent_changed: true, agent_version_changed: false)
      expect(result.success?).to be true
    end
  end

  describe 'attribute accessors' do
    let(:result) { described_class.new(agent_changed: true, agent_version_changed: false) }

    it 'provides predicate methods' do
      expect(result.agent_changed?).to be true
      expect(result.agent_version_changed?).to be false
    end

    it 'provides attribute readers' do
      expect(result.agent_changed).to be true
      expect(result.agent_version_changed).to be false
    end
  end
end
