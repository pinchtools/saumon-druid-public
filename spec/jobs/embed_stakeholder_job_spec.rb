require 'rails_helper'

RSpec.describe EmbedStakeholderJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:stakeholder) { create(:an_stakeholder, first_name: 'Jean', last_name: 'Dupont') }
    let(:embedding_service) { instance_double(Llm::OpenrouterEmbeddingService) }
    let(:embedding_vector) { Array.new(1024, 0.1) }

    before do
      allow(Llm::OpenrouterEmbeddingService).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:embed).and_return([ embedding_vector ])
    end

    context 'with valid stakeholder and content' do
      it 'creates an_search record with embedding' do
        expect {
          described_class.new.perform(stakeholder.id)
        }.to change { An::Search.count }.by(1)

        search = An::Search.find_by(searchable: stakeholder)
        expect(search).to be_present
        expect(search.embedding).to eq(embedding_vector)
      end
    end

    context 'when content is blank' do
      before do
        allow_any_instance_of(An::Stakeholder).to receive(:vector_search_content).and_return('')
      end

      it 'does not create an_search record' do
        expect {
          described_class.new.perform(stakeholder.id)
        }.not_to change { An::Search.count }
      end
    end

    context 'when stakeholder is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.new.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when embedding service fails' do
      before do
        allow(embedding_service).to receive(:embed).and_raise(Llm::OpenrouterEmbeddingService::EmbeddingError.new('API error'))
      end

      it 'raises error for retry' do
        expect {
          described_class.new.perform(stakeholder.id)
        }.to raise_error(Llm::OpenrouterEmbeddingService::EmbeddingError)
      end

      it 'does not create search record' do
        expect {
          begin
            described_class.new.perform(stakeholder.id)
          rescue Llm::OpenrouterEmbeddingService::EmbeddingError
            # Swallow error to test side effects
          end
        }.not_to change { An::Search.count }
      end
    end

    context 'when network timeout occurs' do
      before do
        allow(embedding_service).to receive(:embed).and_raise(Net::ReadTimeout)
      end

      it 'raises error for retry' do
        expect {
          described_class.new.perform(stakeholder.id)
        }.to raise_error(Net::ReadTimeout)
      end

      it 'does not create search record' do
        expect {
          begin
            described_class.new.perform(stakeholder.id)
          rescue Net::ReadTimeout
            # Swallow error to test side effects
          end
        }.not_to change { An::Search.count }
      end
    end
  end
end
