module Llm
  class SelfHostedEmbeddingService
    class EmbeddingError < StandardError; end

    def initialize
      @host = ENV.fetch("EMBEDDING_HOST")
    end

    def embed(*texts)
      response = HTTParty.post(
        "#{@host}/embed",
        body: { "texts": texts }.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: 30
      )

      raise EmbeddingError, "Embedding server error: #{response.body}" unless response.success?

      parsed = JSON.parse(response.body)
      parsed["embeddings"] || raise(EmbeddingError, "No embedding returned")
    end
  end
end
