require 'rails_helper'

RSpec.describe SaumonNet::Client do
  let(:valid_config) do
    SaumonNet::Configuration.new.tap do |config|
      config.api_token = 'test_token'
      config.base_url = 'https://api.example.com'
      config.timeout = 30
      config.retries = 3
      config.debug = false
    end
  end

  let(:invalid_config) do
    SaumonNet::Configuration.new.tap do |config|
      config.api_token = nil
    end
  end

  describe '#initialize' do
    context 'with valid configuration' do
      it 'initializes successfully' do
        expect { described_class.new(valid_config) }.not_to raise_error
      end

      it 'uses provided configuration' do
        client = described_class.new(valid_config)
        expect(client.configuration).to eq(valid_config)
      end

      it 'sets HTTParty base_uri' do
        expect(described_class).to receive(:base_uri).with('https://api.example.com')
        described_class.new(valid_config)
      end

      it 'sets HTTParty timeout' do
        expect(described_class).to receive(:default_timeout).with(30)
        described_class.new(valid_config)
      end
    end

    context 'with debug enabled' do
      before { valid_config.debug = true }

      it 'enables debug output' do
        expect(described_class).to receive(:debug_output).with($stdout)
        described_class.new(valid_config)
      end
    end

    context 'without configuration' do
      before do
        allow(SaumonNet).to receive(:configuration).and_return(valid_config)
      end

      it 'uses global configuration' do
        client = described_class.new
        expect(client.configuration).to eq(valid_config)
      end
    end

    context 'with invalid configuration' do
      it 'raises ConfigurationError' do
        expect { described_class.new(invalid_config) }.to raise_error(
          SaumonNet::ConfigurationError,
          /API token is required/
        )
      end
    end
  end

  describe '#get' do
    let(:client) { described_class.new(valid_config) }
    let(:response_body) { { 'data' => [ { 'id' => 1 } ] }.to_json }

    before do
      stub_request(:get, 'https://api.example.com/test')
        .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'makes GET request with proper headers' do
      client.get('/test')

      expect(WebMock).to have_requested(:get, 'https://api.example.com/test')
        .with(
          headers: {
            'Authorization' => 'Bearer test_token',
            'Content-Type' => 'application/json',
            'Accept' => 'application/json'
          }
        )
    end

    it 'returns parsed JSON response' do
      result = client.get('/test')
      expect(result).to eq({ 'data' => [ { 'id' => 1 } ] })
    end

    it 'passes query parameters' do
      stub_request(:get, 'https://api.example.com/test')
        .with(query: { page: 1, limit: 10 })
        .to_return(status: 200, body: '{}')

      client.get('/test', query: { page: 1, limit: 10 })

      expect(WebMock).to have_requested(:get, 'https://api.example.com/test')
        .with(query: { page: 1, limit: 10 })
    end

    it 'merges custom headers' do
      stub_request(:get, 'https://api.example.com/test')
        .with(
          headers: {
            'Authorization' => 'Bearer test_token',
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
            'X-Custom' => 'value'
          }
        )
        .to_return(status: 200, body: '{}')

      client.get('/test', headers: { 'X-Custom' => 'value' })

      expect(WebMock).to have_requested(:get, 'https://api.example.com/test')
        .with(
          headers: {
            'Authorization' => 'Bearer test_token',
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
            'X-Custom' => 'value'
          }
        )
    end

    context 'with empty response body' do
      before do
        stub_request(:get, 'https://api.example.com/empty')
          .to_return(status: 200, body: '', headers: {})
      end

      it 'returns empty hash' do
        result = client.get('/empty')
        expect(result).to eq({})
      end
    end

    context 'with nil response body' do
      before do
        stub_request(:get, 'https://api.example.com/nil')
          .to_return(status: 200, body: nil, headers: {})
      end

      it 'returns empty hash' do
        result = client.get('/nil')
        expect(result).to eq({})
      end
    end
  end

  describe 'error handling' do
    let(:client) { described_class.new(valid_config) }

    describe 'HTTP errors' do
      it 'raises AuthenticationError for 401' do
        stub_request(:get, 'https://api.example.com/test')
          .to_return(status: 401, body: '{"error": "Unauthorized"}')

        expect { client.get('/test') }.to raise_error(
          SaumonNet::AuthenticationError,
          'Unauthorized'
        )
      end

      it 'raises NotFoundError for 404' do
        stub_request(:get, 'https://api.example.com/test')
          .to_return(status: 404, body: '{"error": "Not found"}')

        expect { client.get('/test') }.to raise_error(
          SaumonNet::NotFoundError,
          'Not found'
        )
      end

      it 'raises ClientError for 400-499' do
        stub_request(:get, 'https://api.example.com/test')
          .to_return(status: 422, body: '{"error": "Unprocessable entity"}')

        expect { client.get('/test') }.to raise_error(
          SaumonNet::ClientError,
          'Unprocessable entity'
        )
      end

      it 'raises ServerError for 500-599' do
        stub_request(:get, 'https://api.example.com/test')
          .to_return(status: 500, body: '{"error": "Internal server error"}')

        expect { client.get('/test') }.to raise_error(
          SaumonNet::ServerError,
          'Internal server error'
        )
      end

      it 'uses default error message when response has no error field' do
        stub_request(:get, 'https://api.example.com/test')
          .to_return(status: 404, body: '{"error": "Not Found"}')

        expect { client.get('/test') }.to raise_error(
          SaumonNet::NotFoundError,
          'Not Found'
        )
      end

      it 'handles invalid JSON in error response' do
        stub_request(:get, 'https://api.example.com/test')
          .to_return(status: 500, body: 'Invalid JSON')

        expect { client.get('/test') }.to raise_error(
          SaumonNet::ServerError,
          'HTTP 500'
        )
      end
    end

    describe 'network errors' do
      before { valid_config.retries = 2 }

      it 'retries on timeout and eventually raises HttpError' do
        stub_request(:get, 'https://api.example.com/test')
          .to_timeout.times(2)

        expect { client.get('/test') }.to raise_error(
          SaumonNet::HttpError,
          /Request timeout/
        )
      end

      it 'raises HttpError for socket errors' do
        stub_request(:get, 'https://api.example.com/test')
          .to_raise(SocketError.new('Connection refused'))

        expect { client.get('/test') }.to raise_error(
          SaumonNet::HttpError,
          /Connection error/
        )
      end

      it 'succeeds after retry' do
        stub_request(:get, 'https://api.example.com/test')
          .to_timeout.then
          .to_return(status: 200, body: '{"success": true}')

        result = client.get('/test')
        expect(result).to eq({ 'success' => true })
      end
    end

    describe 'JSON parsing errors' do
      it 'raises HttpError for invalid JSON' do
        stub_request(:get, 'https://api.example.com/test')
          .to_return(status: 200, body: 'Invalid JSON{')

        expect { client.get('/test') }.to raise_error(
          SaumonNet::HttpError,
          /Invalid JSON response/
        )
      end
    end
  end
end
