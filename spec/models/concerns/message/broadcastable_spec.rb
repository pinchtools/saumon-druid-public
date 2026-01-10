# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message::Broadcastable do
  let(:conversation) { create(:conversation) }

  describe "#should_broadcast?" do
    context "when assistant message" do
      let(:message) { create(:message, :assistant, :processing, conversation: conversation) }

      it "returns true when status changes" do
        message.update!(status: Message::STATUS_COMPLETED)

        expect(message.send(:should_broadcast?)).to be true
      end

      it "returns true when content changes" do
        message.update!(content: "New content")

        expect(message.send(:should_broadcast?)).to be true
      end

      it "returns false when neither status nor content changes" do
        message.update!(metadata: { "foo" => "bar" })

        expect(message.send(:should_broadcast?)).to be false
      end
    end

    context "when user message" do
      let(:message) { create(:message, :user, conversation: conversation) }

      it "returns false even when content changes" do
        message.update!(content: "Updated question")

        expect(message.send(:should_broadcast?)).to be false
      end
    end
  end

  describe "after_update_commit callback" do
    let(:message) { create(:message, :assistant, :processing, conversation: conversation) }

    it "broadcasts replace when assistant message status changes" do
      expect(message).to receive(:broadcast_replace_to).with(conversation)

      message.update!(status: Message::STATUS_COMPLETED)
    end

    it "broadcasts replace when assistant message content changes" do
      expect(message).to receive(:broadcast_replace_to).with(conversation)

      message.update!(content: "Here is the response")
    end

    it "does not broadcast when user message changes" do
      user_message = create(:message, :user, conversation: conversation)

      expect(user_message).not_to receive(:broadcast_replace_to)

      user_message.update!(content: "Updated question")
    end

    it "does not broadcast when irrelevant attributes change" do
      expect(message).not_to receive(:broadcast_replace_to)

      message.update!(metadata: { "key" => "value" })
    end
  end
end
