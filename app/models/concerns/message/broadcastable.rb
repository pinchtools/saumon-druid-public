# frozen_string_literal: true

module Message::Broadcastable
  extend ActiveSupport::Concern

  included do
    include Turbo::Broadcastable

    after_update_commit :broadcast_message_update, if: :should_broadcast?
  end

  private

  def should_broadcast?
    assistant? && (saved_change_to_status? || saved_change_to_content?)
  end

  def broadcast_message_update
    broadcast_replace_to conversation
  end
end
