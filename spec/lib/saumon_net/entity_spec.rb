require 'rails_helper'

RSpec.describe SaumonNet::Entity do
  let(:mock_client) { instance_double(SaumonNet::Client) }
  let(:entity) { described_class.new(mock_client) }

  describe '#initialize' do
    context 'with client provided' do
      it 'uses the provided client' do
        entity = described_class.new(mock_client)
        expect(entity.client).to eq(mock_client)
      end
    end

    context 'without client provided' do
      before do
        allow(described_class).to receive(:default_client).and_return(mock_client)
      end

      it 'uses the default client' do
        entity = described_class.new
        expect(entity.client).to eq(mock_client)
      end
    end
  end

  describe '.default_client' do
    before do
      # Setup valid configuration for default client
      allow(SaumonNet).to receive(:configuration).and_return(
        SaumonNet::Configuration.new.tap { |c| c.api_token = 'test_token' }
      )
    end

    after do
      # Clean up memoized client
      described_class.reset_default_client!
    end

    it 'creates and memoizes a default client' do
      client1 = described_class.default_client
      client2 = described_class.default_client
      expect(client1).to be_a(SaumonNet::Client)
      expect(client1).to be(client2)
    end
  end

  describe '.reset_default_client!' do
    before do
      # Setup valid configuration for default client
      allow(SaumonNet).to receive(:configuration).and_return(
        SaumonNet::Configuration.new.tap { |c| c.api_token = 'test_token' }
      )
    end

    after do
      # Clean up memoized client
      described_class.reset_default_client!
    end

    it 'resets the memoized default client' do
      client1 = described_class.default_client
      described_class.reset_default_client!
      client2 = described_class.default_client
      expect(client1).not_to be(client2)
    end
  end

  describe '.list' do
    let(:expected_response) { { 'data' => [ { 'id' => 1 } ], 'meta' => { 'total' => 1 } } }

    before do
      allow(described_class).to receive(:new).and_return(entity)
      allow(entity).to receive(:list).and_return(expected_response)
    end

    it 'delegates to instance method with default parameters' do
      result = described_class.list

      expect(entity).to have_received(:list).with(page: 1, per_page: 100, since: nil, type: nil)
      expect(result).to eq(expected_response)
    end

    it 'passes through custom parameters' do
      described_class.list(page: 2, per_page: 50, since: '2023-01-01', type: 'user')

      expect(entity).to have_received(:list).with(page: 2, per_page: 50, since: '2023-01-01', type: 'user')
    end
  end

  describe '.retrieve' do
    let(:expected_response) { { 'data' => { 'id' => 123 } } }

    before do
      allow(described_class).to receive(:new).and_return(entity)
      allow(entity).to receive(:retrieve).and_return(expected_response)
    end

    it 'delegates to instance method' do
      result = described_class.retrieve(123)

      expect(entity).to have_received(:retrieve).with(123)
      expect(result).to eq(expected_response)
    end
  end

  describe '.list_all' do
    let(:expected_entities) { [ { 'id' => 1 }, { 'id' => 2 } ] }

    before do
      allow(described_class).to receive(:new).and_return(entity)
      allow(entity).to receive(:list_all).and_return(expected_entities)
    end

    it 'delegates to instance method with default parameters' do
      result = described_class.list_all

      expect(entity).to have_received(:list_all).with(per_page: 100, since: nil, type: nil)
      expect(result).to eq(expected_entities)
    end

    it 'passes through custom parameters and block' do
      block = proc { |entities| entities }
      described_class.list_all(per_page: 50, since: '2023-01-01', type: 'user', &block)

      expect(entity).to have_received(:list_all).with(per_page: 50, since: '2023-01-01', type: 'user')
    end
  end

  describe '#list' do
    it 'makes GET request to entities endpoint with default parameters' do
      allow(mock_client).to receive(:get).and_return({})

      entity.list

      expect(mock_client).to have_received(:get).with(
        '/api/v1/entities',
        query: { page: 1, per_page: 100 }
      )
    end

    it 'includes optional parameters when provided' do
      allow(mock_client).to receive(:get).and_return({})

      entity.list(page: 2, per_page: 50, since: '2023-01-01T00:00:00Z', type: 'user')

      expect(mock_client).to have_received(:get).with(
        '/api/v1/entities',
        query: {
          page: 2,
          per_page: 50,
          since: '2023-01-01T00:00:00Z',
          type: 'user'
        }
      )
    end

    it 'enforces maximum per_page of 100' do
      allow(mock_client).to receive(:get).and_return({})

      entity.list(per_page: 200)

      expect(mock_client).to have_received(:get).with(
        '/api/v1/entities',
        query: { page: 1, per_page: 100 }
      )
    end

    it 'omits nil parameters from query' do
      allow(mock_client).to receive(:get).and_return({})

      entity.list(page: 1, per_page: 50, since: nil, type: nil)

      expect(mock_client).to have_received(:get).with(
        '/api/v1/entities',
        query: { page: 1, per_page: 50 }
      )
    end

    it 'returns the client response' do
      expected_response = { 'data' => [ { 'id' => 1 } ] }
      allow(mock_client).to receive(:get).and_return(expected_response)

      result = entity.list
      expect(result).to eq(expected_response)
    end
  end

  describe '#retrieve' do
    it 'makes GET request to specific entity endpoint' do
      allow(mock_client).to receive(:get).and_return({})

      entity.retrieve(123)

      expect(mock_client).to have_received(:get).with('/api/v1/entities/123')
    end

    it 'returns the client response' do
      expected_response = { 'data' => { 'id' => 123 } }
      allow(mock_client).to receive(:get).and_return(expected_response)

      result = entity.retrieve(123)
      expect(result).to eq(expected_response)
    end
  end

  describe '#list_all' do
    let(:page1_response) do
      {
        'data' => [ { 'id' => 1 }, { 'id' => 2 } ],
        'meta' => { 'has_next_page' => true }
      }
    end

    let(:page2_response) do
      {
        'data' => [ { 'id' => 3 }, { 'id' => 4 } ],
        'meta' => { 'has_next_page' => false }
      }
    end

    context 'without block' do
      it 'fetches all pages and returns combined entities' do
        allow(entity).to receive(:list)
          .with(page: 1, per_page: 100, since: nil, type: nil)
          .and_return(page1_response)
        allow(entity).to receive(:list)
          .with(page: 2, per_page: 100, since: nil, type: nil)
          .and_return(page2_response)

        result = entity.list_all

        expect(result).to eq([
          { 'id' => 1 }, { 'id' => 2 }, { 'id' => 3 }, { 'id' => 4 }
        ])
      end

      it 'stops when no more pages' do
        allow(entity).to receive(:list)
          .with(page: 1, per_page: 100, since: nil, type: nil)
          .and_return(page2_response)

        result = entity.list_all

        expect(result).to eq([ { 'id' => 3 }, { 'id' => 4 } ])
      end

      it 'stops when page has no data' do
        empty_response = { 'data' => [], 'meta' => {} }
        allow(entity).to receive(:list)
          .with(page: 1, per_page: 100, since: nil, type: nil)
          .and_return(empty_response)

        result = entity.list_all

        expect(result).to eq([])
      end

      it 'handles missing data field' do
        response_without_data = { 'meta' => { 'has_next_page' => false } }
        allow(entity).to receive(:list)
          .with(page: 1, per_page: 100, since: nil, type: nil)
          .and_return(response_without_data)

        result = entity.list_all

        expect(result).to eq([])
      end
    end

    context 'with block' do
      it 'yields each page to the block and returns nil' do
        allow(entity).to receive(:list)
          .with(page: 1, per_page: 100, since: nil, type: nil)
          .and_return(page1_response)
        allow(entity).to receive(:list)
          .with(page: 2, per_page: 100, since: nil, type: nil)
          .and_return(page2_response)

        yielded_pages = []
        result = entity.list_all { |page| yielded_pages << page }

        expect(yielded_pages).to eq([
          [ { 'id' => 1 }, { 'id' => 2 } ],
          [ { 'id' => 3 }, { 'id' => 4 } ]
        ])
        expect(result).to be_nil
      end
    end

    it 'passes custom parameters to list method' do
      allow(entity).to receive(:list).and_return(page2_response)

      entity.list_all(per_page: 50, since: '2023-01-01', type: 'user')

      expect(entity).to have_received(:list).with(
        page: 1, per_page: 50, since: '2023-01-01', type: 'user'
      )
    end

    it 'handles missing meta information gracefully' do
      response_without_meta = { 'data' => [ { 'id' => 1 } ] }
      allow(entity).to receive(:list)
        .with(page: 1, per_page: 100, since: nil, type: nil)
        .and_return(response_without_meta)

      result = entity.list_all

      expect(result).to eq([ { 'id' => 1 } ])
    end
  end
end
