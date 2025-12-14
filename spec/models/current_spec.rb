require "rails_helper"

RSpec.describe Current do
  after { described_class.reset }


  describe ".with_session" do
    it "sets session_id for the duration of the block" do
      captured_session_id = nil

      described_class.with_session("custom-session") do
        captured_session_id = described_class.session_id
      end

      expect(captured_session_id).to eq("custom-session")
    end

    it "generates a UUID when no id is provided" do
      captured_session_id = nil

      described_class.with_session do
        captured_session_id = described_class.session_id
      end

      expect(captured_session_id).to match(/\A[\h-]{36}\z/)
    end

    it "resets session_id after the block" do
      described_class.with_session("temp-session") do
        # inside block
      end

      expect(described_class.session_id).to be_nil
    end

    it "resets session_id even when an exception is raised" do
      expect {
        described_class.with_session("error-session") do
          raise "test error"
        end
      }.to raise_error("test error")

      expect(described_class.session_id).to be_nil
    end

    it "returns the block result" do
      result = described_class.with_session { "block result" }

      expect(result).to eq("block result")
    end
  end
end
