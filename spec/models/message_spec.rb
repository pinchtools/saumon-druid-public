# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message, type: :model do
  describe "associations" do
    it { should belong_to(:conversation) }
  end

  describe "validations" do
    it { should validate_inclusion_of(:role).in_array(Message::ROLES) }
    it { should validate_inclusion_of(:status).in_array(Message::STATUSES) }

    context "content presence" do
      it "requires content for user messages" do
        message = build(:message, :user, content: nil)
        expect(message).not_to be_valid
        expect(message.errors[:content]).to include("can't be blank")
      end

      it "allows empty content for assistant messages" do
        message = build(:message, :assistant, content: "")
        expect(message).to be_valid
      end
    end
  end

  describe "scopes" do
    let(:conversation) { create(:conversation) }

    describe ".by_role" do
      let!(:user_message) { create(:message, :user, conversation: conversation) }
      let!(:assistant_message) { create(:message, :assistant, conversation: conversation) }

      it "filters by role" do
        expect(described_class.by_role(Message::ROLE_USER)).to include(user_message)
        expect(described_class.by_role(Message::ROLE_USER)).not_to include(assistant_message)
      end
    end

    describe ".pending" do
      let!(:pending_message) { create(:message, :pending, conversation: conversation) }
      let!(:completed_message) { create(:message, :completed, conversation: conversation) }

      it "returns only pending messages" do
        expect(described_class.pending).to include(pending_message)
        expect(described_class.pending).not_to include(completed_message)
      end
    end

    describe ".chronological" do
      let!(:old_message) { create(:message, conversation: conversation, created_at: 2.hours.ago) }
      let!(:new_message) { create(:message, conversation: conversation, created_at: 1.hour.ago) }

      it "orders by created_at ascending" do
        expect(described_class.chronological.first).to eq(old_message)
        expect(described_class.chronological.last).to eq(new_message)
      end
    end
  end

  describe "role predicates" do
    describe "#user?" do
      it { expect(build(:message, :user).user?).to be true }
      it { expect(build(:message, :assistant).user?).to be false }
    end

    describe "#assistant?" do
      it { expect(build(:message, :assistant).assistant?).to be true }
      it { expect(build(:message, :user).assistant?).to be false }
    end
  end

  describe "status predicates" do
    describe "#pending?" do
      it { expect(build(:message, :pending).pending?).to be true }
      it { expect(build(:message, :completed).pending?).to be false }
    end

    describe "#processing?" do
      it { expect(build(:message, :processing).processing?).to be true }
    end

    describe "#completed?" do
      it { expect(build(:message, :completed).completed?).to be true }
    end

    describe "#failed?" do
      it { expect(build(:message, :failed).failed?).to be true }
    end
  end

  describe "#mark_processing!" do
    let(:message) { create(:message, :pending) }

    it "updates status to processing" do
      message.mark_processing!
      expect(message.reload.status).to eq(Message::STATUS_PROCESSING)
    end
  end

  describe "#complete!" do
    let(:message) { create(:message, :assistant, :processing, content: "") }

    it "updates content and status" do
      message.complete!("Here is your answer")

      message.reload
      expect(message.content).to eq("Here is your answer")
      expect(message.status).to eq(Message::STATUS_COMPLETED)
    end
  end

  describe "#fail!" do
    let(:message) { create(:message, :assistant, :processing, content: "") }

    it "updates content and status to failed" do
      message.fail!("Something went wrong")

      message.reload
      expect(message.content).to eq("Something went wrong")
      expect(message.status).to eq(Message::STATUS_FAILED)
    end

    it "stores error in metadata" do
      message.fail!("Something went wrong")
      expect(message.reload.metadata["error"]).to eq("Something went wrong")
    end
  end
end
