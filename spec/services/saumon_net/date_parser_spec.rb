require 'rails_helper'

RSpec.describe SaumonNet::DateParser do
  let(:logger) { double('logger') }
  let(:session_id) { 'test-session-id' }

  describe '.parse_date' do
    it 'parses valid date strings' do
      result = described_class.parse_date("1970-09-30")
      expect(result).to eq(Date.parse("1970-09-30"))
    end

    it 'returns nil for blank dates' do
      result = described_class.parse_date("")
      expect(result).to be_nil
    end

    it 'returns nil for nil dates' do
      result = described_class.parse_date(nil)
      expect(result).to be_nil
    end

    it 'returns nil for non-string dates' do
      result = described_class.parse_date(12345)
      expect(result).to be_nil
    end

    it 'does not log when logger is not provided' do
      result = described_class.parse_date("invalid-date")
      expect(result).to be_nil
    end
  end

  describe '.parse_datetime' do
    it 'parses valid datetime strings' do
      result = described_class.parse_datetime("2024-01-15T10:30:00")
      expect(result).to be_a(DateTime)
      expect(result.year).to eq(2024)
      expect(result.month).to eq(1)
      expect(result.day).to eq(15)
    end

    it 'returns nil for blank datetimes' do
      result = described_class.parse_datetime("")
      expect(result).to be_nil
    end

    it 'returns nil for nil datetimes' do
      result = described_class.parse_datetime(nil)
      expect(result).to be_nil
    end

    it 'returns nil for non-string datetimes' do
      result = described_class.parse_datetime(12345)
      expect(result).to be_nil
    end
  end
end
