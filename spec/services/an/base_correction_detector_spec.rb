require 'rails_helper'

RSpec.describe An::BaseCorrectionDetector do
  let(:email) { 'test@example.com' }
  let(:record) { double('record', id: 1, name: 'Test', email: email) }
  let(:session_id) { 'test_session_123' }

  subject { described_class.new(record, session_id: session_id) }

  describe '#correction ' do
    let(:field) { 'email' }
    let(:before_value) { 'old@example.com' }
    let(:after_value) { 'new@example.com' }
    let(:reason) { 'Email format correction' }

    it 'returns properly formatted correction hash' do
      result = subject.correction(
        field,
        before: before_value,
        after: after_value,
        reason: reason
      )

      expect(result).to eq({
        correction_changes: {
          field => {
            'before' => before_value,
            'after' => after_value
          }
        },
        reason: reason,
        correction_type: 'automatic',
        session_id: session_id
      })
    end
  end

  describe '#matches_conditions?' do
    let(:stakeholder) { double('stakeholder', last_name: 'Hollande', first_name: 'François') }
    let(:nested_record) { double('term', capacity: 'president', end_date: nil, an_stakeholder: stakeholder) }
    let(:detector_with_nested) { described_class.new(nested_record, session_id: session_id) }

    context 'with record conditions' do
      it 'matches when values are equal' do
        conditions = { 'record' => { 'id' => record.id, 'name' => record.name } }
        expect(subject.send(:matches_conditions?, conditions)).to be true
      end

      it 'handles nested attributes with dot notation' do
        conditions = { 'record' => { 'an_stakeholder.last_name' => nested_record.an_stakeholder.last_name } }
        expect(detector_with_nested.send(:matches_conditions?, conditions)).to be true
      end
    end

    context 'with special value matchers' do
      let(:blank_record) { double('record', capacity: '', end_date: nil) }
      subject(:blank_detector) { described_class.new(blank_record, session_id: session_id) }

      it 'matches blank values with "blank" keyword' do
        conditions = { 'record' => { 'capacity' => 'blank' } }
        expect(blank_detector.send(:matches_conditions?, conditions)).to be true
      end

      it 'matches nil values with "null" keyword' do
        conditions = { 'record' => { 'end_date' => 'null' } }
        expect(blank_detector.send(:matches_conditions?, conditions)).to be true
      end

      it 'matches nil values with nil' do
        conditions = { 'record' => { 'end_date' => nil } }
        expect(blank_detector.send(:matches_conditions?, conditions)).to be true
      end
    end

    context 'with nil conditions' do
      it 'returns true for nil conditions' do
        expect(subject.send(:matches_conditions?, nil)).to be true
      end
    end
  end

  describe '#resolve_value' do
    it 'resolves simple attribute' do
      value = subject.send(:resolve_value, record, 'id')
      expect(value).to eq(record.id)
    end

    it 'resolves nested attribute with dot notation' do
      nested_obj = double('nested', value: 'test')
      parent = double('parent', nested: nested_obj)
      value = subject.send(:resolve_value, parent, 'nested.value')
      expect(value).to eq(parent.nested.value)
    end
  end

  describe '#values_match?' do
    it 'matches equal values' do
      expect(subject.send(:values_match?, 'active', 'active')).to be true
    end

    it 'does not match different values' do
      expect(subject.send(:values_match?, 'active', 'inactive')).to be false
    end

    it 'matches blank values with "blank" keyword' do
      expect(subject.send(:values_match?, '', 'blank')).to be true
      expect(subject.send(:values_match?, nil, 'blank')).to be true
    end

    it 'matches nil with "null" keyword' do
      expect(subject.send(:values_match?, nil, 'null')).to be true
      expect(subject.send(:values_match?, nil, nil)).to be true
    end
  end

  describe '#apply_correction' do
    let(:config) do
      {
        'name' => 'test_correction',
        'correction' => {
          'field' => 'status',
          'before' => 'old',
          'after' => 'new',
          'reason' => 'Status update required'
        }
      }
    end

    it 'applies correction from config hash' do
      result = subject.send(:apply_correction, config)

      expect(result[:correction_changes]['status']['before']).to eq(config['correction']['before'])
      expect(result[:correction_changes]['status']['after']).to eq(config['correction']['after'])
      expect(result[:reason]).to eq(config['correction']['reason'])
      expect(result[:correction_type]).to eq('automatic')
      expect(result[:session_id]).to eq(session_id)
    end
  end
end
