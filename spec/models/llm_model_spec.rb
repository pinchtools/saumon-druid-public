# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LlmModel, type: :model do
  describe 'validations' do
    subject do
      described_class.new(
        external_id: 'test-model-id',
        name: 'Test Model',
        family: 'test-family',
        provider: 'test-provider'
      )
    end

    it { should validate_presence_of(:external_id) }
    it { should validate_uniqueness_of(:external_id) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:family) }
    it { should validate_presence_of(:provider) }
    it { should validate_inclusion_of(:tier).in_array(described_class::TIERS).allow_nil }
  end
end
