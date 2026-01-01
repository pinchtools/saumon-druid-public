class Agent::Tool::PositionCatalog < RubyLLM::Tool
  description "Searches for matching position/term labels in the database to help normalize user queries. Pass the user's informal position term and get back the top matching canonical labels (e.g., 'numéro 1' → ['Président de l'Assemblée nationale'])."

  params do
    string :search_query, description: "The informal position term to search for (e.g., 'numéro 1', 'vice président')"
  end

  def execute(search_query:)
    # Make only lexical query as a start.
    # When the response is empty the model try by it-self to re-label the position
    # to maximize the chance for the runner to resolve the query.
    # Use Vector and cache system later-on.

    matching_labels = An::Term
                        .lexical_search(search_query)
                        .limit(5)
                        .pluck(:label)

    {
      note: "#{self.class} #{search_query} results found: #{matching_labels.count}",
      content: matching_labels
    }
  rescue => e
    { error: e.message }
  end
end
