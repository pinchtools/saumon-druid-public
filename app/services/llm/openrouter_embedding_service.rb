class Llm::OpenrouterEmbeddingService
  class EmbeddingError < StandardError; end

  OPENROUTER_API_URL = "https://openrouter.ai/api/v1/embeddings"
  MODEL = "mistralai/mistral-embed-2312"

  def initialize
    @api_key = ENV["OPENROUTER_API_KEY"] || Rails.application.credentials.dig(:openai_api_key)
    raise EmbeddingError, "OpenRouter API key not configured" if @api_key.blank?
  end

  def embed(*texts)
    response = HTTParty.post(
      OPENROUTER_API_URL,
      body: {
        model: MODEL,
        input: texts
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@api_key}",
        "HTTP-Referer" => "https://github.com/saumon-druid",
        "X-Title" => "Saumon Druid"
      },
      timeout: 30
    )

    raise EmbeddingError, "OpenRouter API error: #{response.body}" unless response.success?

    parsed = JSON.parse(response.body)

    embeddings = parsed.dig("data")&.map { |item| item["embedding"] }
    raise EmbeddingError, "No embeddings returned" if embeddings.blank?

    embeddings
  end
end
