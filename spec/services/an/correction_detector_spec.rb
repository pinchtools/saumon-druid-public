require 'rails_helper'

RSpec.describe An::CorrectionDetector do
  let(:session_id) { 'test_session_123' }
  let(:api_data) { { 'uid' => 'PA123', 'typeOrgane' => 'ASSEMBLEE' } }
  let(:term) { create(:an_term) }

  subject { described_class.new(term, api_data, session_id: session_id) }

  describe '#initialize' do
    context 'with An::Term record' do
      it 'creates a TermCorrectionDetector delegator' do
        expect(subject.instance_variable_get(:@delegator)).to be_a(An::TermCorrectionDetector)
      end

      it 'passes correct parameters to delegator' do
        delegator = subject.instance_variable_get(:@delegator)

        expect(delegator.record).to eq(term)
        expect(delegator.api_data).to eq(api_data)
        expect(delegator.session_id).to eq(session_id)
      end
    end

    context 'with unsupported record type' do
      let(:unsupported_record) { create(:an_country) }

      it 'raises ArgumentError with helpful message' do
        expect {
          described_class.new(unsupported_record, api_data, session_id: session_id)
        }.to raise_error(ArgumentError, /No correction detector found for Country/)
      end
    end
  end

  describe '#detect_all' do
    context 'expect to delegate to a specific detector' do
      it 'delegates to TermCorrectionDetector' do
        expect(subject.instance_variable_get(:@delegator)).to receive(:detect_all)
        subject.detect_all
      end

      it 'returns the result of TermCorrectionDetector#detect_all' do
        expect(subject.detect_all).to be_an(Array)
      end
    end
  end

  describe '#detect_one' do
    context 'expect to delegate to a specific detector' do
      let(:correction_name) { 'first_correction' }
      it 'delegates to TermCorrectionDetector' do
        expect(subject.instance_variable_get(:@delegator)).to receive(:detect_one).with(correction_name)
        subject.detect_one(correction_name)
      end
    end
  end

  describe 'private methods' do
    describe '#record_class_name' do
      it 'returns demodulized class name' do
        result = subject.send(:record_class_name)
        expect(result).to eq('Term')
      end
    end

    describe '#delegator_class_name' do
      it 'returns the correct detector class' do
        result = subject.send(:delegator_class_name)
        expect(result).to eq(An::TermCorrectionDetector)
      end
    end
  end
end
