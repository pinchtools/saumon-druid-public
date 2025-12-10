require 'rails_helper'

RSpec.describe An::Concerns::Searchable, type: :model do
  describe 'scopes' do
    let!(:matching_stakeholder) do
      stakeholder = create(:an_stakeholder, first_name: 'Jean', last_name: 'Dupont')
      stakeholder.sync_lexical_search_content
      stakeholder
    end

    let!(:non_matching_stakeholder) do
      stakeholder = create(:an_stakeholder, first_name: 'Marie', last_name: 'Martin')
      stakeholder.sync_lexical_search_content
      stakeholder
    end

    let(:searchable_class) { An::Stakeholder }

    describe '.fts_search' do
      it 'returns stakeholders matching FTS query' do
        results = searchable_class.fts_search('dupont')
        expect(results).to include(matching_stakeholder)
        expect(results).not_to include(non_matching_stakeholder)
      end
    end

    describe '.trigram_search' do
      it 'returns stakeholders matching trigram similarity query' do
        results = searchable_class.trigram_search('dupon')
        expect(results).to include(matching_stakeholder)
        expect(results).not_to include(non_matching_stakeholder)
      end
    end

    describe '.lexical_search' do
      it 'returns stakeholders matching combined lexical search' do
        results = searchable_class.lexical_search('dupont')
        expect(results).to include(matching_stakeholder)
        expect(results).not_to include(non_matching_stakeholder)
      end
    end

    describe '.semantic_search' do
      let(:query) { 'french deputy' }
      let(:query_embedding) { Array.new(1024, 0.1) }
      let(:matching_embedding) { query_embedding }
      let(:non_matching_embedding) { Array.new(1024, 0.9) }
      let(:embedding_service) { instance_double(Llm::OpenrouterEmbeddingService) }

      before do
        matching_stakeholder.search_record.update_embedding(matching_embedding)
        matching_stakeholder.search_record.save!

        non_matching_stakeholder.search_record.update_embedding(non_matching_embedding)
        non_matching_stakeholder.search_record.save!

        allow(Llm::OpenrouterEmbeddingService).to receive(:new).and_return(embedding_service)
        allow(embedding_service).to receive(:embed).with(query).and_return([ query_embedding ])
      end

      it 'returns stakeholders with similar embeddings' do
        results = searchable_class.semantic_search(query, limit: 10)
        expect(results).to include(matching_stakeholder)
        expect(results).not_to include(non_matching_embedding)
      end

      context 'when embedding service fails' do
        before do
          allow(embedding_service).to receive(:embed).and_raise(Llm::OpenrouterEmbeddingService::EmbeddingError.new('API error'))
        end

        it 'returns empty result' do
          results = searchable_class.semantic_search(query, limit: 10)
          expect(results).to be_empty
        end
      end
    end
  end

  describe '#search_record' do
    let(:stakeholder) { build(:an_stakeholder) }

    context 'when an_search exists' do
      let!(:search) { create(:an_search, searchable: stakeholder) }

      it 'returns existing an_search' do
        expect(stakeholder.search_record).to eq(search)
      end
    end

    context 'when an_search does not exist' do
      it 'builds new an_search' do
        expect(stakeholder.search_record).to be_new_record
      end
    end
  end

  describe '#sync_lexical_search_content' do
    let(:stakeholder) { create(:an_stakeholder, first_name: 'Jean', last_name: 'Dupont') }

    it 'updates fts and trigram content' do
      expect { stakeholder.sync_lexical_search_content }.
        to change { stakeholder.an_search&.fts }.to(include("jean", "dupont")).
          and change { stakeholder.an_search&.trigram }.to(include("jean dupont"))
    end
  end
end
