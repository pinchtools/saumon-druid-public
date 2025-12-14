module Eventable
  extend ActiveSupport::Concern

  included do
    has_many :events, as: :eventable, dependent: :nullify
  end

  # Track an event on this model
  #
  # @param action [Symbol, String] The action name (e.g., :created, :updated)
  # @param category [Symbol, String] Event category (defaults based on class)
  # @param payload [Hash] Additional metadata to store
  # @param severity [Symbol] :debug, :info, :warn, :error
  # @param session_id [String] UUID to correlate related events
  #
  # @example
  #   stakeholder.track_event(:imported, payload: { source: "saumon_net" })
  #
  def track_event(action, category: nil, payload: {}, severity: :info, session_id: nil)
    Event.create!(
      category: category || default_event_category,
      action: action.to_s,
      severity: severity.to_s,
      eventable: self,
      payload: payload,
      session_id: session_id || Current.session_id,
      request_id: Current.request_id,
      job_id: Current.job_id,
      actor: Current.user,
      actor_type: Current.user&.class&.name
    )
  end

  private

  def default_event_category
    case self.class.name
    when /^An::/
      "data"
    when /Job$/
      "system"
    else
      "application"
    end
  end
end
