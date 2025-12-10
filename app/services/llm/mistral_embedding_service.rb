module Llm
  class MistralEmbeddingService
    class EmbeddingError < StandardError; end

    MISTRAL_API_URL = "https://api.mistral.ai/v1/embeddings"
    MODEL = "mistral-embed"

    def initialize
      @api_key = ENV["MISTRAL_API_KEY"] || Rails.application.credentials.dig(:mistral_api_key)
      raise EmbeddingError, "Mistral API key not configured" if @api_key.blank?
    end

    def embed(*texts)
      response = HTTParty.post(
        MISTRAL_API_URL,
        body: {
          model: MODEL,
          input: texts
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{@api_key}"
        },
        timeout: 30
      )

      raise EmbeddingError, "Mistral API error: #{response.body}" unless response.success?

      parsed = JSON.parse(response.body)

      # Mistral returns embeddings in OpenAI format: { data: [{ embedding: [...] }, ...] }
      embeddings = parsed.dig("data")&.map { |item| item["embedding"] }
      raise EmbeddingError, "No embeddings returned" if embeddings.blank?

      embeddings
    end
  end
end
