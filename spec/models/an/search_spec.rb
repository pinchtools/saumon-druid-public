require 'rails_helper'

RSpec.describe An::Search, type: :model do
  describe 'associations' do
    it { should belong_to(:searchable) }
  end

  describe 'scopes' do
    let(:stakeholder1) { create(:an_stakeholder, first_name: 'Jean', last_name: 'Dupont') }
    let(:stakeholder2) { create(:an_stakeholder, first_name: 'Marie', last_name: 'Martin') }

    let!(:matching_search) do
      search = create(:an_search, searchable: stakeholder1)
      search.update_fts('jean dupont député paris')
      search.update_trigram('jean dupont député paris')
      search.save!
      search
    end

    let!(:non_matching_search) do
      search = create(:an_search, searchable: stakeholder2)
      search.update_fts('marie martin ministre lyon')
      search.update_trigram('marie martin ministre lyon')
      search.save!
      search
    end

    describe '.fts_search' do
      it 'returns searches matching FTS query' do
        results = described_class.fts_search('dupont')
        expect(results).to include(matching_search)
        expect(results).not_to include(non_matching_search)
      end

      it 'uses french configuration' do
        expect(described_class.fts_search('député').to_sql).to include("plainto_tsquery('french'")
      end
    end

    describe '.trigram_search' do
      it 'returns searches matching trigram similarity query' do
        results = described_class.trigram_search('dupond')
        expect(results).to include(matching_search)
        expect(results).not_to include(non_matching_search)
      end
    end

    describe '.lexical_search' do
      it 'returns searches matching combined lexical search' do
        results = described_class.lexical_search('dupont')
        expect(results).to include(matching_search)
        expect(results).not_to include(non_matching_search)
      end
    end
  end

  describe '.semantic_search' do
    let(:query) { 'french deputy' }
    let(:query_embedding) { Array.new(1024, 0.1) }
    let(:matching_embedding) { query_embedding }
    let(:non_matching_embedding) { Array.new(1024, 0.9) }
    let(:embedding_service) { instance_double(Llm::OpenrouterEmbeddingService) }

    let(:stakeholder1) { create(:an_stakeholder) }
    let(:stakeholder2) { create(:an_stakeholder) }

    let!(:matching_search) do
      search = create(:an_search, searchable: stakeholder1)
      search.update_embedding(matching_embedding)
      search.save!
      search
    end

    let!(:non_matching_search) do
      search = create(:an_search, searchable: stakeholder2)
      search.update_embedding(non_matching_embedding)
      search.save!
      search
    end

    before do
      allow(Llm::OpenrouterEmbeddingService).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:embed).with(query).and_return([ query_embedding ])
    end

    it 'returns searches with similar embeddings' do
      results = described_class.semantic_search(query, limit: 10)
      expect(results).to include(matching_search)
    end

    context 'when embedding service fails' do
      before do
        allow(embedding_service).to receive(:embed).
          and_raise(Llm::OpenrouterEmbeddingService::EmbeddingError.new('API error'))
      end

      it 'create an event' do
        expect { described_class.semantic_search(query) }.to change {
          Event.by_action("embedding_server_error").count
        }.by(1)
      end

      it 'returns empty array' do
        expect(described_class.semantic_search(query)).to eq([])
      end
    end
  end

  describe '#update_fts' do
    let(:search) { build(:an_search) }
    let(:content) { 'Test Content' }

    it 'updates trigram column' do
      search.update_fts(content)
      expect(search.fts).to include('test', 'content')
    end
  end

  describe '#update_trigram' do
    let(:search) { build(:an_search) }
    let(:content) { 'Test Content' }

    it 'updates trigram column' do
      search.update_trigram(content)
      expect(search.trigram).to eq('test content')
    end
  end

  describe '#update_embedding' do
    let(:search) { build(:an_search) }
    let(:embedding) { [ 0.1, 0.2, 0.3 ] }

    it 'updates embedding column' do
      search.update_embedding(embedding)
      expect(search.embedding).to eq(embedding)
    end
  end
end
