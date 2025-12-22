require 'rails_helper'

RSpec.describe Agent::Input::QueryPlannerInput do
  describe 'validations' do
    let(:valid_attributes) do
      {
        question: "Who is the current president of France?",
        trace_id: "test-trace-id",
        message_id: "test-message-id"
      }
    end

    it 'is valid with valid attributes' do
      input = described_class.new(valid_attributes)
      expect(input).to be_valid
    end

    it 'requires question' do
      input = described_class.new(valid_attributes.except(:question))
      expect(input).not_to be_valid
      expect(input.errors[:question]).to include("can't be blank")
    end

    it 'requires trace_id' do
      input = described_class.new(valid_attributes.except(:trace_id))
      expect(input).not_to be_valid
      expect(input.errors[:trace_id]).to include("can't be blank")
    end

    it 'requires message_id' do
      input = described_class.new(valid_attributes.except(:message_id))
      expect(input).not_to be_valid
      expect(input.errors[:message_id]).to include("can't be blank")
    end

    it 'validates question length minimum' do
      input = described_class.new(valid_attributes.merge(question: "Hi"))
      expect(input).not_to be_valid
      expect(input.errors[:question]).to include("is too short (minimum is 5 characters)")
    end

    it 'validates question length maximum' do
      long_question = "a" * 501
      input = described_class.new(valid_attributes.merge(question: long_question))
      expect(input).not_to be_valid
      expect(input.errors[:question]).to include("is too long (maximum is 500 characters)")
    end

    it 'accepts valid question length' do
      input = described_class.new(valid_attributes.merge(question: "What is the current legislature?"))
      expect(input).to be_valid
    end
  end
end
