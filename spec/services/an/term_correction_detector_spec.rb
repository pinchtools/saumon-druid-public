require 'rails_helper'

RSpec.describe An::TermCorrectionDetector do
  let(:stakeholder) { create(:an_stakeholder, last_name: 'Dupont') }
  let(:body) { create(:an_body) }
  let(:session_id) { 'test_session_123' }

  subject { described_class.new(record, session_id: session_id) }

  describe '#detect_all' do
    let(:corrections_config) do
      [
        {
          "name" => "test_correction",
          "conditions" => {
            "record" => { "capacity" => "president" }
          },
          "correction" => {
            "field" => "capacity",
            "before" => "president",
            "after" => "president-du-senat",
            "reason" => "Test correction reason"
          }
        }
      ]
    end

    before do
      stub_const('An::TermCorrectionDetector::CORRECTIONS_CONFIG', corrections_config)
    end

    context 'when conditions match' do
      let(:record) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: 'president') }

      it 'applies the correction' do
        corrections = subject.detect_all
        fix = corrections.first

        expect(corrections.size).to eq(1)
        expect(fix[:correction_changes]['capacity']['before']).to eq(record.capacity)
        expect(fix[:correction_changes]['capacity']['after']).to eq(corrections_config.first['correction']['after'])
        expect(fix[:reason]).to eq(corrections_config.first['correction']['reason'])
        expect(fix[:correction_type]).to eq('automatic')
        expect(fix[:session_id]).to eq(session_id)
      end
    end

    context 'when record condition does not match' do
      let(:record) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: 'membre') }

      it 'does not apply the correction' do
        expect(subject.detect_all).to be_empty
      end
    end

    context 'when multiple corrections match' do
      let(:corrections_config) do
        [
          {
            "name" => "first_correction",
            "conditions" => { "record" => { "capacity" => "blank" } },
            "correction" => {
              "field" => "capacity",
              "before" => nil,
              "after" => "membre",
              "reason" => "First correction"
            }
          },
          {
            "name" => "second_correction",
            "conditions" => { "record" => { "end_date" => "null" } },
            "correction" => {
              "field" => "end_date",
              "before" => nil,
              "after" => "2024-01-01",
              "reason" => "Second correction"
            }
          }
        ]
      end
      let(:record) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: nil, end_date: nil) }

      it 'applies all matching corrections' do
        corrections = subject.detect_all

        expect(corrections.size).to eq(2)
        expect(corrections.map { |c| c[:correction_changes].keys }.flatten).to contain_exactly('capacity', 'end_date')
      end
    end
  end

  describe '#detect_one' do
    let(:corrections_config) do
      [
        {
          "name" => "test_correction",
          "conditions" => {
            "record" => { "capacity" => "president" }
          },
          "correction" => {
            "field" => "capacity",
            "before" => "president",
            "after" => "president-du-senat",
            "reason" => "Test correction reason"
          }
        },
        {
          "name" => "another_correction",
          "conditions" => {
            "record" => { "capacity" => "membre" }
          },
          "correction" => {
            "field" => "capacity",
            "before" => "membre",
            "after" => "membre-corrected",
            "reason" => "Another correction reason"
          }
        }
      ]
    end

    before do
      stub_const('An::TermCorrectionDetector::CORRECTIONS_CONFIG', corrections_config)
    end

    context 'when correction is found by name and conditions match' do
      let(:record) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: 'president') }

      it 'applies the correction' do
        fix = subject.detect_one('test_correction')

        expect(fix).not_to be_nil
        expect(fix[:correction_changes]['capacity']['before']).to eq('president')
        expect(fix[:correction_changes]['capacity']['after']).to eq('president-du-senat')
        expect(fix[:reason]).to eq('Test correction reason')
        expect(fix[:correction_type]).to eq('automatic')
        expect(fix[:session_id]).to eq(session_id)
      end
    end

    context 'when correction is found by name but conditions do not match' do
      let(:record) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: 'autre') }

      it 'returns nil' do
        result = subject.detect_one('test_correction')

        expect(result).to be_nil
      end
    end

    context 'when correction is not found by name' do
      let(:record) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: 'president') }

      it 'returns nil' do
        result = subject.detect_one('nonexistent_correction')

        expect(result).to be_nil
      end
    end
  end
end
