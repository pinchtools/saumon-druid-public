class Event::ErrorReporterJob < ApplicationJob
  queue_as :monitoring

  discard_on ActiveRecord::RecordNotFound

  def perform(event_id)
    event = Event.find(event_id)
    Event::ErrorReporter.new(event).report
  end
end
