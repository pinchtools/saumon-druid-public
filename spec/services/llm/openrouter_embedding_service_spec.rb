require 'rails_helper'

RSpec.describe Llm::OpenrouterEmbeddingService do
  let(:api_key) { 'test_api_key' }
  let(:api_url) { "https://openrouter.ai/api/v1/embeddings" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENROUTER_API_KEY").and_return(api_key)
  end

  describe '#initialize' do
    context 'when API key is configured' do
      it 'initializes successfully' do
        expect { described_class.new }.not_to raise_error
      end
    end

    context 'when API key is missing' do
      let(:api_key) { nil }

      before do
        allow(Rails.application.credentials).to receive(:dig).with(:openai_api_key).and_return(nil)
      end

      it 'raises EmbeddingError' do
        expect { described_class.new }.to raise_error(Llm::OpenrouterEmbeddingService::EmbeddingError, "OpenRouter API key not configured")
      end
    end
  end

  describe '#embed' do
    subject(:service) { described_class.new }

    let(:text) { "test text" }
    let(:embedding_vector) { Array.new(1024, 0.1) }
    let(:success_response) do
      {
        data: [
          { embedding: embedding_vector }
        ]
      }
    end

    context 'with successful API response' do
      before do
        stub_request(:post, api_url)
          .with(
            body: hash_including(model: "mistralai/mistral-embed-2312", input: [ text ]),
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{api_key}",
              'HTTP-Referer' => 'https://github.com/saumon-druid',
              'X-Title' => 'Saumon Druid'
            }
          )
          .to_return(status: 200, body: success_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns embeddings array' do
        result = service.embed(text)
        expect(result).to eq([ embedding_vector ])
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:post, api_url)
          .to_return(status: 500, body: "Internal Server Error")
      end

      it 'raises EmbeddingError' do
        expect { service.embed(text) }.to raise_error(Llm::OpenrouterEmbeddingService::EmbeddingError, /OpenRouter API error/)
      end
    end

    context 'when response has no embeddings' do
      before do
        stub_request(:post, api_url)
          .to_return(status: 200, body: { data: [] }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises EmbeddingError' do
        expect { service.embed(text) }.to raise_error(Llm::OpenrouterEmbeddingService::EmbeddingError, "No embeddings returned")
      end
    end
  end
end
