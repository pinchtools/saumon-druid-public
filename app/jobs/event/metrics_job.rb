class Event::MetricsJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(event_id)
    event = Event.find(event_id)
    Event::Metrics.new(event).record
  end
end
