module ServiceEventable
  extend ActiveSupport::Concern

  included do
    attr_accessor :session_id
  end

  def track_event(action, category: nil, payload: {}, severity: :info)
    Event.create!(
      category: category || service_event_category,
      action: action.to_s,
      severity: severity.to_s,
      eventable_type: self.class.name,
      eventable_id: nil,
      payload: payload.merge(service_context),
      session_id: session_id || Current.session_id,
      request_id: Current.request_id,
      job_id: Current.job_id,
      actor: Current.user,
      actor_type: Current.user&.class&.name
    )
  end

  private

  def service_event_category
    "service"
  end

  def service_context
    {}
  end
end
