class EmbedStakeholderJob < ApplicationJob
  queue_as :default

  retry_on Llm::OpenrouterEmbeddingService::EmbeddingError, wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

  def perform(stakeholder_id)
    stakeholder = An::Stakeholder.find(stakeholder_id)
    content = stakeholder.vector_search_content

    return if content.blank?

    embedding = Llm::OpenrouterEmbeddingService.new.embed(content)

    search_record = stakeholder.search_record
    search_record.update_embedding(embedding&.first)
    search_record.save!
  end
end
