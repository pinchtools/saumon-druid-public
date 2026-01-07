# frozen_string_literal: true

class Conversation < ApplicationRecord
  include Eventable

  # Status constants
  STATUS_ACTIVE = "active"
  STATUS_COMPLETED = "completed"
  STATUS_FAILED = "failed"
  STATUS_CANCELLED = "cancelled"
  STATUSES = [ STATUS_ACTIVE, STATUS_COMPLETED, STATUS_FAILED, STATUS_CANCELLED ].freeze

  has_many :messages, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :session_id, presence: true

  scope :active, -> { where(status: STATUS_ACTIVE) }
  scope :completed, -> { where(status: STATUS_COMPLETED) }
  scope :recent, -> { order(created_at: :desc) }

  def active?
    status == STATUS_ACTIVE
  end

  def complete!
    update!(status: STATUS_COMPLETED)
    track_event(:completed)
  end

  def fail!(reason: nil)
    update!(status: STATUS_FAILED, metadata: metadata.merge("failure_reason" => reason))
    track_event(:failed, severity: :error, payload: { reason: reason })
  end

  def cancel!
    update!(status: STATUS_CANCELLED)
    track_event(:cancelled)
  end

  def add_user_message(content)
    messages.create!(role: Message::ROLE_USER, content: content, status: Message::STATUS_COMPLETED)
  end

  def add_assistant_message
    messages.create!(role: Message::ROLE_ASSISTANT, content: "", status: Message::STATUS_PENDING)
  end

  def last_user_message
    messages.where(role: Message::ROLE_USER).order(created_at: :desc).first
  end

  def last_message
    messages.order(created_at: :desc).first
  end

  private

  def default_event_category
    "conversation"
  end
end
