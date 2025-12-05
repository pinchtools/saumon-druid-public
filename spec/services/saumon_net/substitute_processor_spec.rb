require 'rails_helper'

RSpec.describe SaumonNet::SubstituteProcessor do
  let(:term) { create(:an_term) }
  let(:substitute_uid) { "PA999999" }
  let!(:substitute_stakeholder) { create(:an_stakeholder, uid: substitute_uid) }
  let(:session_id) { 'test-session-id' }
  let(:start_date) { "2022-06-22" }
  let(:end_date) { "2023-06-22" }

  let(:mandate_data) do
    {
      "suppleants" => {
        "suppleant" => [
          {
            "suppleantRef" => substitute_uid,
            "dateDebut" => start_date,
            "dateFin" => end_date
          }
        ]
      }
    }
  end

  describe '#process' do
    let(:data) { mandate_data }
    subject(:processor) { described_class.new(term, data, session_id) }

    it 'creates a substitute when valid data is provided' do
      expect {
        processor.process
      }.to change(An::Substitute, :count).by(1)

      substitute = An::Substitute.last
      expect(substitute.an_term).to eq(term)
      expect(substitute.an_stakeholder).to eq(substitute_stakeholder)
      expect(substitute.start_date).to be_present
      expect(substitute.end_date).to be_present
    end

    it 'handles multiple substitutes' do
      second_start_date = "2024-01-01"
      second_end_date = "2024-12-31"

      mandate_data["suppleants"]["suppleant"] = [
        {
          "suppleantRef" => substitute_uid,
          "dateDebut" => start_date,
          "dateFin" => end_date
        },
        {
          "suppleantRef" => substitute_uid,
          "dateDebut" => second_start_date,
          "dateFin" => second_end_date
        }
      ]

      expect { processor.process }.to change(An::Substitute, :count).by(2)
    end

    it 'does not create duplicate substitutes for same term, stakeholder, and start_date' do
      create(:an_substitute,
        an_term: term,
        an_stakeholder: substitute_stakeholder,
        start_date: DateTime.parse(start_date)
      )

      expect { processor.process }.not_to change(An::Substitute, :count)
    end

    it 'creates different substitutes for same term and stakeholder with different start_dates' do
      different_start_date = "2021-01-01"

      create(:an_substitute,
        an_term: term,
        an_stakeholder: substitute_stakeholder,
        start_date: DateTime.parse(different_start_date)
      )

      expect { processor.process }.to change(An::Substitute, :count).by(1)
    end

    describe "when stakeholder is not found" do
      let!(:substitute_stakeholder) { nil }

      it 'skips when stakeholder is not found' do
        expect { processor.process }.not_to change(An::Substitute, :count)
      end
    end

    describe "when no suppleants data is provided" do
      let(:data) { {} }

      it 'returns early when no suppleants data' do
        expect { processor.process }.not_to change(An::Substitute, :count)
      end
    end

    describe "when suppleant key is missing" do
      let(:mandate_data) { { "suppleants" => {} } }

      it 'returns early when suppleant key is missing' do
        expect { processor.process }.not_to change(An::Substitute, :count)
      end
    end
  end
end
