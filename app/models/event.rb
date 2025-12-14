class Event < ApplicationRecord
  # Explicitly set primary key since we use custom id without Rails-managed PK
  # (Required for TimescaleDB hypertable compatibility)
  self.primary_key = "id"

  # Disable updated_at - events are immutable
  self.record_timestamps = false

  validates :category, presence: true
  validates :action, presence: true
  validates :severity, inclusion: { in: %w[debug info warn error] }

  belongs_to :eventable, polymorphic: true, optional: true
  belongs_to :actor, polymorphic: true, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :by_action, ->(act) { where(action: act) }
  scope :errors, -> { where(severity: "error") }
  scope :warnings, -> { where(severity: "warn") }
  scope :in_session, ->(sid) { where(session_id: sid) }
  scope :for_request, ->(rid) { where(request_id: rid) }
  scope :since, ->(time) { where("created_at >= ?", time) }
  scope :until, ->(time) { where("created_at <= ?", time) }

  def full_action
    "#{category}.#{action}"
  end

  after_create_commit :notify_observer

  private

  def notify_observer
    Event::Observer.new(self).observe
  end
end
