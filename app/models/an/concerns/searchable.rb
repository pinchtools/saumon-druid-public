module An::Concerns::Searchable
  extend ActiveSupport::Concern

  included do
    has_one :an_search, as: :searchable, class_name: "An::Search", dependent: :destroy

    scope :fts_search, ->(query) {
      joins(:an_search).merge(An::Search.fts_search(query))
    }

    scope :trigram_search, ->(query) {
      joins(:an_search).merge(An::Search.trigram_search(query))
    }

    scope :lexical_search, ->(query) {
      joins(:an_search).merge(An::Search.lexical_search(query))
    }

    def self.semantic_search(query_embedding, limit: 10)
      search_results = An::Search.where(searchable_type: name)
                                 .semantic_search(query_embedding, limit: limit)

      ids = search_results.map(&:searchable_id).map(&:to_i)

      order_clause = Arel::Nodes::NamedFunction.new(
        "array_position",
        [
          Arel::Nodes::SqlLiteral.new("ARRAY[#{ids.join(',')}]::bigint[]"),
          Arel::Nodes::SqlLiteral.new("#{table_name}.id")
        ]
      )

      where(id: ids)
        .joins(:an_search)
        .order(order_clause)
        .limit(limit)
    end
  end

  def search_record
    an_search || build_an_search
  end

  def sync_lexical_search_content
    record = search_record
    record.update_fts(fts_search_content)
    record.update_trigram(trigram_search_content)
    record.save!
  end
end
