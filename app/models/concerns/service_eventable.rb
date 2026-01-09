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
      payload: build_payload(payload),
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

  # Builds the final payload by merging:
  # 1. Automatic context (message_id, conversation_id)
  # 2. Service-specific context
  # 3. Provided payload
  def build_payload(payload)
    automatic_context.merge(service_context).merge(payload)
  end

  # Automatically includes message_id and conversation_id from Current context
  # This ensures all events can be traced back to their message/conversation
  def automatic_context
    context = {}
    context[:message_id] = Current.message_id if Current.message_id
    context[:conversation_id] = Current.conversation_id if Current.conversation_id
    context
  end
end
