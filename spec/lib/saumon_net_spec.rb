require 'rails_helper'

RSpec.describe SaumonNet do
  describe '.configure' do
    it 'yields the configuration object' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.configuration)
    end

    it 'resets the default client when configuration changes' do
      expect(SaumonNet::Entity).to receive(:reset_default_client!)
      described_class.configure { |c| c.api_token = 'test' }
    end

    it 'allows setting configuration values' do
      described_class.configure do |config|
        config.api_token = 'test_token'
        config.base_url = 'https://test.example.com'
        config.timeout = 60
      end

      config = described_class.configuration
      expect(config.api_token).to eq('test_token')
      expect(config.base_url).to eq('https://test.example.com')
      expect(config.timeout).to eq(60)
    end
  end

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(described_class.configuration).to be_a(SaumonNet::Configuration)
    end

    it 'memoizes the configuration instance' do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to be(config2)
    end
  end

  describe 'error classes' do
    it 'defines base Error class' do
      expect(SaumonNet::Error).to be < StandardError
    end

    it 'defines HTTP error hierarchy' do
      expect(SaumonNet::HttpError).to be < SaumonNet::Error
      expect(SaumonNet::AuthenticationError).to be < SaumonNet::HttpError
      expect(SaumonNet::NotFoundError).to be < SaumonNet::HttpError
      expect(SaumonNet::ClientError).to be < SaumonNet::HttpError
      expect(SaumonNet::ServerError).to be < SaumonNet::HttpError
    end

    it 'defines ConfigurationError' do
      expect(SaumonNet::ConfigurationError).to be < SaumonNet::Error
    end
  end

  describe 'autoloading' do
    it 'autoloads Client' do
      expect { SaumonNet::Client }.not_to raise_error
    end

    it 'autoloads Configuration' do
      expect { SaumonNet::Configuration }.not_to raise_error
    end
  end
end
