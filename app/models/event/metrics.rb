class Event::Metrics
  attr_reader :event

  def initialize(event)
    @event = event
  end

  def record
    return unless defined?(NewRelic::Agent)

    record_event_counter
    record_custom_attributes
    record_action_specific_metrics
  end

  private

  def record_event_counter
    NewRelic::Agent.increment_metric("Custom/Events/#{event.category}/#{event.action}")
    NewRelic::Agent.increment_metric("Custom/Events/Total")

    if event.severity == "error"
      NewRelic::Agent.increment_metric("Custom/Events/Errors/#{event.category}")
    end
  end

  def record_custom_attributes
    NewRelic::Agent.add_custom_attributes(
      event_category: event.category,
      event_action: event.action,
      event_session_id: event.session_id,
      event_severity: event.severity
    )
  end

  def record_action_specific_metrics
    case event.full_action
    when "import.completed"
      record_import_metrics
    when "import.entity_processed"
      record_entity_metrics
    when "health.check_performed"
      record_health_metrics
    end
  end

  def record_import_metrics
    payload = event.payload.symbolize_keys
    entity_type = payload[:entity_type] || "unknown"

    %i[processed created updated failed].each do |metric|
      if (value = payload[metric])
        NewRelic::Agent.record_metric(
          "Custom/SaumonNet/Import/#{entity_type}/#{metric.to_s.camelize}",
          value
        )
      end
    end
  end

  def record_entity_metrics
    payload = event.payload.symbolize_keys
    entity_type = payload[:entity_type] || "unknown"

    NewRelic::Agent.increment_metric("Custom/SaumonNet/Entity/#{entity_type}/Processed")
  end

  def record_health_metrics
    payload = event.payload.symbolize_keys

    if payload[:response_time]
      NewRelic::Agent.record_metric(
        "Custom/SaumonNet/Health/ResponseTime",
        payload[:response_time]
      )
    end
  end
end
