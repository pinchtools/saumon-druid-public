require 'rails_helper'

RSpec.describe An::TermCorrectionDetector do
  let(:stakeholder) { create(:an_stakeholder, last_name: 'Dupont') }
  let(:body) { create(:an_body) }
  let(:session_id) { 'test_session_123' }

  subject { described_class.new(record, api_data, session_id: session_id) }

  describe '#detect' do
    let(:corrections_config) do
      [
        {
          "name" => "test_correction",
          "conditions" => {
            "api_data" => { "typeOrgane" => "SENAT" },
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
      let(:api_data) { { 'typeOrgane' => 'SENAT' } }

      it 'applies the correction' do
        corrections = subject.detect
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
      let(:api_data) { { 'typeOrgane' => 'SENAT' } }

      it 'does not apply the correction' do
        expect(subject.detect).to be_empty
      end
    end

    context 'when api_data condition does not match' do
      let(:record) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: 'president') }
      let(:api_data) { { 'typeOrgane' => 'ASSEMBLEE' } }

      it 'does not apply the correction' do
        expect(subject.detect).to be_empty
      end
    end

    context 'when both conditions do not match' do
      let(:record) { create(:an_term, an_stakeholder: stakeholder, an_body: body, capacity: 'membre') }
      let(:api_data) { { 'typeOrgane' => 'ASSEMBLEE' } }

      it 'does not apply the correction' do
        corrections = subject.detect

        expect(corrections).to be_empty
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
      let(:api_data) { {} }

      it 'applies all matching corrections' do
        corrections = subject.detect

        expect(corrections.size).to eq(2)
        expect(corrections.map { |c| c[:correction_changes].keys }.flatten).to contain_exactly('capacity', 'end_date')
      end
    end
  end
end
