require 'rails_helper'

RSpec.describe Agent::Tool::PositionCatalog, type: :model do
  subject(:tool) { described_class.new }

  describe 'tool configuration' do
    it 'has a description' do
      expect(described_class.description).to be_present
      expect(described_class.description).to include('position')
    end

    it 'inherits from RubyLLM::Tool' do
      expect(described_class.ancestors).to include(RubyLLM::Tool)
    end
  end

  describe '#execute' do
    let!(:president_term) { create(:an_term, label: "Président de l'Assemblée nationale") }
    let!(:vice_president_term) { create(:an_term, label: "Vice-président de l'Assemblée nationale") }
    let!(:deputy_term) { create(:an_term, label: "Député") }
    let!(:finance_commission_president) { create(:an_term, label: "Président de la commission des finances") }
    let!(:questeur_term) { create(:an_term, label: "Questeur") }

    before do
      An::Term.find_each(&:sync_lexical_search_content)
    end

    context 'with matching results' do
      it 'returns matching labels for exact match' do
        result = tool.execute(search_query: 'président')

        expect(result[:content]).to include("Président de l'Assemblée nationale")
        expect(result[:content]).to include("Président de la commission des finances")
      end

      it 'returns matching labels for partial match' do
        result = tool.execute(search_query: 'vice')

        expect(result[:content]).to include("Vice-président de l'Assemblée nationale")
      end

      it 'performs case-insensitive search' do
        result = tool.execute(search_query: 'PRÉSIDENT')

        expect(result[:content]).to include("Président de l'Assemblée nationale")
      end

      it 'handles fuzzy matching' do
        result = tool.execute(search_query: 'presiden')

        expect(result[:content]).to include("Président de l'Assemblée nationale")
      end

      it 'handles queries without accents' do
        result = tool.execute(search_query: 'president')

        expect(result[:content]).to include("Président de l'Assemblée nationale")
      end
    end

    context 'with result limiting' do
      before do
        10.times { |i| create(:an_term, label: "Président de commission #{i}").sync_lexical_search_content }
      end

      it 'limits results to 5 items' do
        result = tool.execute(search_query: 'président')

        expect(result[:content].size).to be <= 5
      end
    end

    context 'with no matching results' do
      it 'returns empty array when no matches found' do
        result = tool.execute(search_query: 'nonexistent position xyz')

        expect(result[:content]).to eq([])
        expect(result[:note]).to include('results found: 0')
      end
    end

    context 'with edge cases' do
      it 'handles empty search query' do
        result = tool.execute(search_query: '')

        expect(result[:content]).to be_an(Array)
      end

      it 'handles special characters' do
        result = tool.execute(search_query: "président's")

        expect(result[:content]).to be_an(Array)
      end
    end

    context 'when an error occurs' do
      before do
        allow(An::Term).to receive(:lexical_search).and_raise(StandardError.new('Database error'))
      end

      it 'returns error hash' do
        result = tool.execute(search_query: 'président')

        expect(result).to have_key(:error)
        expect(result[:error]).to eq('Database error')
      end
    end
  end
end
