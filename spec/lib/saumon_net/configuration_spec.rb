require 'rails_helper'

RSpec.describe SaumonNet::Configuration do
  subject(:configuration) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(configuration.base_url).to eq('http://localhost:3004')
      expect(configuration.api_token).to be_nil
      expect(configuration.timeout).to eq(30)
      expect(configuration.retries).to eq(3)
      expect(configuration.debug).to be(false)
    end
  end

  describe '#valid?' do
    context 'when api_token is nil' do
      before { configuration.api_token = nil }

      it 'returns false' do
        expect(configuration).not_to be_valid
      end
    end

    context 'when api_token is empty string' do
      before { configuration.api_token = '' }

      it 'returns false' do
        expect(configuration).not_to be_valid
      end
    end

    context 'when api_token is present' do
      before { configuration.api_token = 'test_token' }

      it 'returns true' do
        expect(configuration).to be_valid
      end
    end
  end

  describe 'attribute accessors' do
    it 'allows setting and getting base_url' do
      configuration.base_url = 'https://api.example.com'
      expect(configuration.base_url).to eq('https://api.example.com')
    end

    it 'allows setting and getting api_token' do
      configuration.api_token = 'secret_token'
      expect(configuration.api_token).to eq('secret_token')
    end

    it 'allows setting and getting timeout' do
      configuration.timeout = 60
      expect(configuration.timeout).to eq(60)
    end

    it 'allows setting and getting retries' do
      configuration.retries = 5
      expect(configuration.retries).to eq(5)
    end

    it 'allows setting and getting debug' do
      configuration.debug = true
      expect(configuration.debug).to be(true)
    end
  end
end
