# frozen_string_literal: true

require "rails_helper"

RSpec.describe Conversation, type: :model do
  describe "associations" do
    it { should have_many(:messages).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_inclusion_of(:status).in_array(Conversation::STATUSES) }
    it { should validate_presence_of(:session_id) }
  end

  describe "scopes" do
    describe ".active" do
      let!(:active_conversation) { create(:conversation, status: Conversation::STATUS_ACTIVE) }
      let!(:completed_conversation) { create(:conversation, status: Conversation::STATUS_COMPLETED) }

      it "returns only active conversations" do
        expect(described_class.active).to include(active_conversation)
        expect(described_class.active).not_to include(completed_conversation)
      end
    end

    describe ".completed" do
      let!(:active_conversation) { create(:conversation, status: Conversation::STATUS_ACTIVE) }
      let!(:completed_conversation) { create(:conversation, status: Conversation::STATUS_COMPLETED) }

      it "returns only completed conversations" do
        expect(described_class.completed).to include(completed_conversation)
        expect(described_class.completed).not_to include(active_conversation)
      end
    end

    describe ".recent" do
      let!(:old_conversation) { create(:conversation, created_at: 2.days.ago) }
      let!(:new_conversation) { create(:conversation, created_at: 1.hour.ago) }

      it "orders by created_at descending" do
        expect(described_class.recent.first).to eq(new_conversation)
        expect(described_class.recent.last).to eq(old_conversation)
      end
    end
  end

  describe "#active?" do
    it "returns true when status is active" do
      conversation = build(:conversation, status: Conversation::STATUS_ACTIVE)
      expect(conversation.active?).to be true
    end

    it "returns false when status is not active" do
      conversation = build(:conversation, status: Conversation::STATUS_COMPLETED)
      expect(conversation.active?).to be false
    end
  end

  describe "#complete!" do
    let(:conversation) { create(:conversation, status: Conversation::STATUS_ACTIVE) }

    it "updates status to completed" do
      conversation.complete!
      expect(conversation.reload.status).to eq(Conversation::STATUS_COMPLETED)
    end
  end

  describe "#fail!" do
    let(:conversation) { create(:conversation, status: Conversation::STATUS_ACTIVE) }

    it "updates status to failed" do
      conversation.fail!(reason: "Something went wrong")
      expect(conversation.reload.status).to eq(Conversation::STATUS_FAILED)
    end

    it "stores the failure reason in metadata" do
      conversation.fail!(reason: "Something went wrong")
      expect(conversation.reload.metadata["failure_reason"]).to eq("Something went wrong")
    end
  end

  describe "#cancel!" do
    let(:conversation) { create(:conversation, status: Conversation::STATUS_ACTIVE) }

    it "updates status to cancelled" do
      conversation.cancel!
      expect(conversation.reload.status).to eq(Conversation::STATUS_CANCELLED)
    end
  end

  describe "#add_user_message" do
    let(:conversation) { create(:conversation) }

    it "creates a user message with completed status" do
      message = conversation.add_user_message("Hello, world!")

      expect(message).to be_persisted
      expect(message.role).to eq(Message::ROLE_USER)
      expect(message.content).to eq("Hello, world!")
      expect(message.status).to eq(Message::STATUS_COMPLETED)
    end
  end

  describe "#add_assistant_message" do
    let(:conversation) { create(:conversation) }

    it "creates an assistant message with pending status" do
      message = conversation.add_assistant_message

      expect(message).to be_persisted
      expect(message.role).to eq(Message::ROLE_ASSISTANT)
      expect(message.content).to eq("")
      expect(message.status).to eq(Message::STATUS_PENDING)
    end
  end

  describe "#last_user_message" do
    let(:conversation) { create(:conversation) }

    before do
      conversation.add_user_message("First question")
      conversation.add_assistant_message
      conversation.add_user_message("Second question")
    end

    it "returns the most recent user message" do
      expect(conversation.last_user_message.content).to eq("Second question")
    end
  end

  describe "#last_message" do
    let(:conversation) { create(:conversation) }

    before do
      conversation.add_user_message("Question")
      conversation.add_assistant_message
    end

    it "returns the most recent message regardless of role" do
      expect(conversation.last_message.role).to eq(Message::ROLE_ASSISTANT)
    end
  end
end
