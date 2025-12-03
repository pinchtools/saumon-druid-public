require 'rails_helper'

RSpec.describe An::CorrectionApplier do
  let(:session_id) { 'test_session_123' }
  let(:stakeholder) { create(:an_stakeholder, last_name: 'Dupont') }
  let(:body) { create(:an_body) }
  let(:term) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: 'president') }

  subject { described_class.new(term, session_id: session_id) }

  describe '#detect_all' do
    let(:detector) { instance_double(An::CorrectionDetector) }
    let(:corrections) do
      [
        {
          correction_changes: { 'capacity' => { 'before' => 'president', 'after' => 'président' } },
          reason: 'Accent correction',
          correction_type: 'automatic',
          session_id: session_id
        },
        {
          correction_changes: { 'end_date' => { 'before' => nil, 'after' => '2024-01-01' } },
          reason: 'End date correction',
          correction_type: 'automatic',
          session_id: session_id
        }
      ]
    end

    before do
      allow(subject).to receive(:detector).and_return(detector)
      allow(detector).to receive(:detect_all).and_return(corrections)
    end

    it 'appends detected corrections to corrections_data' do
      subject.detect_all
      expect(subject.corrections_data).to eq(corrections)
    end

    it 'returns self for chaining' do
      expect(subject.detect_all).to eq(subject)
    end
  end

  describe '#detect_one' do
    let(:detector) { instance_double(An::CorrectionDetector) }
    let(:correction_name) { 'capacity_accent_correction' }
    let(:correction) do
      {
        correction_changes: { 'capacity' => { 'before' => 'president', 'after' => 'président' } },
        reason: 'Accent correction',
        correction_type: 'automatic',
        session_id: session_id
      }
    end

    before do
      allow(subject).to receive(:detector).and_return(detector)
      allow(detector).to receive(:detect_one).with(correction_name).and_return(correction)
    end

    it 'appends the correction to corrections_data' do
      subject.detect_one(correction_name)
      expect(subject.corrections_data).to eq([ correction ])
    end

    it 'returns self for chaining' do
      expect(subject.detect_one(correction_name)).to eq(subject)
    end

    context 'when called multiple times with different corrections' do
      let(:second_correction_name) { 'end_date_correction' }
      let(:second_correction) do
        {
          correction_changes: { 'end_date' => { 'before' => nil, 'after' => '2024-01-01' } },
          reason: 'End date correction',
          correction_type: 'automatic',
          session_id: session_id
        }
      end

      before do
        allow(detector).to receive(:detect_one).with(second_correction_name).and_return(second_correction)
      end

      it 'accumulates corrections' do
        subject.detect_one(correction_name)
        subject.detect_one(second_correction_name)

        expect(subject.corrections_data).to eq([ correction, second_correction ])
      end
    end
  end

  describe '#apply' do
    context 'with valid corrections' do
      let(:correction_data) do
        {
          correction_changes: { 'capacity' => { 'before' => 'president', 'after' => 'président' } },
          reason: 'Accent correction',
          correction_type: 'automatic',
          session_id: session_id
        }
      end

      before do
        subject.instance_variable_set(:@corrections_data, [ correction_data ])
      end

      it 'creates An::Correction records' do
        expect {
          subject.apply
        }.to change(An::Correction, :count).by(1)
      end

      it 'creates corrections with correct attributes' do
        corrections = subject.apply
        correction = corrections.first

        expect(correction).to be_persisted
        expect(correction.correctable).to eq(term)
        expect(correction.correction_changes).to eq(correction_data[:correction_changes])
        expect(correction.reason).to eq(correction_data[:reason])
        expect(correction.correction_type).to eq(correction_data[:correction_type])
      end

      it 'returns an array of created corrections' do
        corrections = subject.apply
        expect(corrections).to be_an(Array)
        expect(corrections.first).to be_a(An::Correction)
      end
    end

    context 'when correction fails to save' do
      let(:invalid_correction_data) do
        {
          correction_changes: { 'invalid_field' => { 'before' => 'old', 'after' => 'new' } },
          reason: 'Invalid correction',
          correction_type: 'automatic',
          session_id: session_id
        }
      end

      before do
        subject.instance_variable_set(:@corrections_data, [ invalid_correction_data ])
      end

      it 'does not create a correction record' do
        expect {
          subject.apply
        }.not_to change(An::Correction, :count)
      end

      it 'returns nil for failed correction' do
        results = subject.apply
        expect(results).to eq([ nil ])
      end
    end
  end
end
