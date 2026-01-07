# frozen_string_literal: true

class Message < ApplicationRecord
  include Eventable

  # Role constants
  ROLE_USER = "user"
  ROLE_ASSISTANT = "assistant"
  ROLES = [ ROLE_USER, ROLE_ASSISTANT ].freeze

  # Status constants
  STATUS_PENDING = "pending"
  STATUS_PROCESSING = "processing"
  STATUS_COMPLETED = "completed"
  STATUS_FAILED = "failed"
  STATUSES = [ STATUS_PENDING, STATUS_PROCESSING, STATUS_COMPLETED, STATUS_FAILED ].freeze

  belongs_to :conversation

  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :content, presence: true, if: :user?

  scope :by_role, ->(role) { where(role: role) }
  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :processing, -> { where(status: STATUS_PROCESSING) }
  scope :completed, -> { where(status: STATUS_COMPLETED) }
  scope :failed, -> { where(status: STATUS_FAILED) }
  scope :chronological, -> { order(created_at: :asc) }

  def user?
    role == ROLE_USER
  end

  def assistant?
    role == ROLE_ASSISTANT
  end

  def pending?
    status == STATUS_PENDING
  end

  def processing?
    status == STATUS_PROCESSING
  end

  def completed?
    status == STATUS_COMPLETED
  end

  def failed?
    status == STATUS_FAILED
  end

  def mark_processing!
    update!(status: STATUS_PROCESSING)
    track_event(:processing_started)
  end

  def complete!(final_content)
    update!(content: final_content, status: STATUS_COMPLETED)
    track_event(:completed, payload: { content_length: final_content.length })
  end

  def fail!(error_message)
    update!(
      content: error_message,
      status: STATUS_FAILED,
      metadata: metadata.merge("error" => error_message)
    )
    track_event(:failed, severity: :error, payload: { error: error_message.truncate(500) })
  end

  private

  def default_event_category
    "message"
  end
end
