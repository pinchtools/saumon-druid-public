require 'rails_helper'

RSpec.describe SaumonNet::TermProcessor do
  let(:stakeholder) { create(:an_stakeholder) }
  let(:session_id) { 'test-session-id' }
  let(:term_uid) { "TERM123" }
  let(:body_uid) { "PO123456" }
  let(:legislature) { "16" }
  let(:start_date) { "2022-06-22" }

  let(:entity_data) do
    {
      "file_details" => {
        "acteur" => {
          "mandats" => {
            "mandat" => [
              {
                "uid" => term_uid,
                "organes" => { "organeRef" => body_uid },
                "legislature" => legislature,
                "dateDebut" => start_date,
                "dateFin" => nil
              }
            ]
          }
        }
      }
    }
  end

  describe '#process' do
    let!(:body) { create(:an_body, uid: body_uid) }
    let(:data) { entity_data }
    subject(:processor) { described_class.new(stakeholder, data, session_id) }

    it 'processes mandate entries and creates terms' do
      expect { processor.process }.to change(An::Term, :count).by(1)

      term = An::Term.last
      expect(term.uid).to eq(term_uid)
      expect(term.an_stakeholder).to eq(stakeholder)
    end

    describe 'when no mandate entries are present' do
      let(:data) { { "file_details" => { "acteur" => { "mandats" => {} } } } }

      it 'returns early when no mandate entries present' do
        expect { processor.process }.not_to change(An::Term, :count)
      end
    end

    context 'when an exception occurs during processing' do
      let(:logger) { double('logger', error: nil) }
      let(:error_message) { 'Test processing error' }

      before do
        allow_any_instance_of(SaumonNet::TermUpserter).to receive(:upsert).and_raise(StandardError.new(error_message))
        allow(processor).to receive(:logger).and_return(logger)
      end

      it 'logs the error and re-raises the exception' do
        expect { processor.process }.to raise_error(StandardError, error_message)

        expect(logger).to have_received(:error).with(hash_including(
          message: "Failed to process stakeholder terms",
          error: error_message
        ))
      end
    end
  end
end
