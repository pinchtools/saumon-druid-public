module An::Term::SearchContentBuilder
  extend ActiveSupport::Concern

  def fts_search_content
    [
      label.parameterize(separator: " ")
    ].flatten.compact.join("\n")
  end

  def trigram_search_content
    [
      label.parameterize(separator: " ")
    ].flatten.compact.join("\n")
  end
end
