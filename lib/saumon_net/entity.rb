module SaumonNet
  class Entity
    attr_reader :client

    def initialize(client = nil)
      @client = client || self.class.default_client
    end

    class << self
      # Default client instance using global configuration
      def default_client
        @default_client ||= Client.new
      end

      # Reset the default client (useful for testing or configuration changes)
      def reset_default_client!
        @default_client = nil
      end

      # Class methods that delegate to a default instance
      def list(page: 1, per_page: 100, since: nil, type: nil)
        new.list(page: page, per_page: per_page, since: since, type: type)
      end

      def retrieve(id)
        new.retrieve(id)
      end

      def list_all(per_page: 100, since: nil, type: nil, &block)
        new.list_all(per_page: per_page, since: since, type: type, &block)
      end
    end

    # Retrieves a paginated list of entities with optional filtering
    #
    # @param page [Integer] Page number (default: 1)
    # @param per_page [Integer] Items per page (max: 100, default: 100)
    # @param since [String] ISO 8601 datetime string to filter entities updated since this date
    # @param type [String] Filter by entity type
    # @return [Hash] Response containing data array and meta information
    def list(page: 1, per_page: 100, since: nil, type: nil)
      query = build_index_query(page: page, per_page: per_page, since: since, type: type)

      @client.get("/api/v1/entities", query: query)
    end

    # Retrieves details for a specific entity
    #
    # @param id [Integer] Entity ID
    # @return [Hash] Response containing entity data
    def retrieve(id)
      @client.get("/api/v1/entities/#{id}")
    end

    # Retrieves all entities by iterating through all pages
    #
    # @param per_page [Integer] Items per page (max: 100, default: 100)
    # @param since [String] ISO 8601 datetime string to filter entities updated since this date
    # @param type [String] Filter by entity type
    # @yield [Array] Yields each page of entities as an array
    # @return [Array] All entities if no block given
    def list_all(per_page: 100, since: nil, type: nil, &block)
      entities = []
      page = 1

      loop do
        response = list(page: page, per_page: per_page, since: since, type: type)
        page_entities = response.dig("data") || []

        break if page_entities.empty?

        if block_given?
          yield page_entities
        else
          entities.concat(page_entities)
        end

        meta = response.dig("meta") || {}
        break unless meta["has_next_page"]

        page += 1
      end

      block_given? ? nil : entities
    end

    private

    def build_index_query(page:, per_page:, since:, type:)
      query = {
        page: page,
        per_page: [ per_page, 100 ].min # Ensure max 100 per API docs
      }

      query[:since] = since if since
      query[:type] = type if type

      # Remove nil values
      query.compact
    end
  end
end
