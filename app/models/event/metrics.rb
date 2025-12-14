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
    when "health.import_check"
      record_import_health_metrics
    when "health.api_check"
      record_api_health_metrics
    when "health.api_check_failed"
      record_api_failure_metrics
    when "health.queue_check"
      record_queue_health_metrics
    when "health.queue_check_failed"
      record_queue_failure_metrics
    when "health.full_check"
      record_full_health_metrics
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

  def record_import_health_metrics
    payload = event.payload.symbolize_keys
    entity_type = payload[:entity_type]

    if payload[:never_imported]
      NewRelic::Agent.record_metric("Custom/SaumonNet/Health/#{entity_type}/NeverImported", 1)
    else
      NewRelic::Agent.record_metric("Custom/SaumonNet/Health/#{entity_type}/AgeHours", payload[:age_hours]) if payload[:age_hours]
      NewRelic::Agent.record_metric("Custom/SaumonNet/Health/#{entity_type}/Healthy", payload[:healthy] ? 1 : 0)
    end

    if payload[:overall_healthy] != nil
      NewRelic::Agent.record_metric("Custom/SaumonNet/Health/Overall/Healthy", payload[:overall_healthy] ? 1 : 0)
      NewRelic::Agent.record_metric("Custom/SaumonNet/Health/Overall/HealthyEntityCount", payload[:healthy_count] || 0)
      NewRelic::Agent.record_metric("Custom/SaumonNet/Health/Overall/TotalEntityCount", payload[:total_count] || 0)
    end
  end

  def record_api_health_metrics
    payload = event.payload.symbolize_keys

    NewRelic::Agent.record_metric("Custom/SaumonNet/API/ResponseTime", payload[:response_time_ms]) if payload[:response_time_ms]
    NewRelic::Agent.record_metric("Custom/SaumonNet/API/Healthy", payload[:healthy] ? 1 : 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/API/ConnectivityCheck", 1)
  end

  def record_api_failure_metrics
    NewRelic::Agent.record_metric("Custom/SaumonNet/API/Healthy", 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/API/Errors", 1)
  end

  def record_queue_health_metrics
    payload = event.payload.symbolize_keys

    NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Healthy", payload[:healthy] ? 1 : 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/TotalEnqueued", payload[:total_enqueued] || 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/FailedCount", payload[:failed_count] || 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/RetryCount", payload[:retry_count] || 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/ProcessedToday", payload[:processed_today] || 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/FailedToday", payload[:failed_today] || 0)

    # Record individual queue sizes
    payload[:queue_sizes]&.each do |queue_name, size|
      NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Queue/#{queue_name}/Size", size)
    end

    # Record threshold violations
    if payload[:alerts]
      payload[:alerts].each do |alert|
        NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Alerts/#{alert}", 1)
      end
    end
  end

  def record_queue_failure_metrics
    NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Healthy", 0)
  end

  def record_full_health_metrics
    payload = event.payload.symbolize_keys

    NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/Overall", payload[:healthy] ? 1 : 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/ImportsHealthy", payload[:imports_healthy] ? 1 : 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/APIHealthy", payload[:api_healthy] ? 1 : 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/QueuesHealthy", payload[:queues_healthy] ? 1 : 0)
    NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/FailedCheckCount", payload[:failed_check_count] || 0)

    NewRelic::Agent.add_custom_attributes(
      "saumon_net.health_check.timestamp" => payload[:timestamp],
      "saumon_net.health.overall" => payload[:healthy],
      "saumon_net.health.imports" => payload[:imports_healthy],
      "saumon_net.health.api" => payload[:api_healthy],
      "saumon_net.health.queues" => payload[:queues_healthy]
    )
  end
end
