class SaumonNet::HealthMonitoringService
  extend ActiveSupport::Benchmarkable

  class << self
    def logger = Rails.logger

    def track_health_event(action, payload: {}, severity: :info)
      Event.create!(
        category: "health",
        action: action.to_s,
        severity: severity.to_s,
        eventable_type: name,
        eventable_id: nil,
        payload: payload,
        session_id: Current.session_id,
        request_id: Current.request_id,
        job_id: Current.job_id
      )
    end

    def record_successful_import(entity_type, stats = nil)
      cache_data = {
        timestamp: Time.current.iso8601,
        stats: stats&.then { |s|
          {
            processed: s.processed,
            created: s.created,
            updated: s.updated,
            skipped: s.skipped,
            failed: s.failed,
            success_rate: s.success_rate
          }
        }
      }

      Rails.cache.write(
        import_status_key(entity_type),
        cache_data,
        expires_in: 30.days
      )
    end

    def last_import_status(entity_type)
      Rails.cache.read(import_status_key(entity_type))
    end

    def import_health_status
      entity_types = %w[organe pays acteur]
      results = {}
      healthy_count = 0

      entity_types.each do |entity_type|
        last_import = last_import_status(entity_type)

        if last_import.nil?
          results[entity_type] = { status: "never_imported", healthy: false }

          track_health_event(:import_check, payload: {
            entity_type: entity_type,
            never_imported: true,
            healthy: false
          })
        else
          last_time = Time.parse(last_import[:timestamp])
          age_hours = (Time.current - last_time) / 1.hour

          healthy = age_hours < 24
          healthy_count += 1 if healthy

          results[entity_type] = {
            status: healthy ? "healthy" : "stale",
            healthy: healthy,
            last_import: last_import[:timestamp],
            age_hours: age_hours.round(2),
            stats: last_import[:stats]
          }

          track_health_event(:import_check, payload: {
            entity_type: entity_type,
            healthy: healthy,
            age_hours: age_hours.round(2),
            last_import: last_import[:timestamp]
          })
        end
      end

      overall_healthy = results.values.all? { |r| r[:healthy] }

      track_health_event(:import_check, payload: {
        overall_healthy: overall_healthy,
        healthy_count: healthy_count,
        total_count: entity_types.size
      })

      {
        overall_healthy: overall_healthy,
        entity_types: results
      }
    end

    def api_health_check
      start_time = Time.current

      result = benchmark "SaumonNet API health check" do
        configure_saumon_net

        SaumonNet::Entity.list_all(type: "organe") do |entities|
          response_time = ((Time.current - start_time) * 1000).round(2)

          track_health_event(:api_check, payload: {
            healthy: true,
            response_time_ms: response_time,
            entity_count: entities.size
          })

          return {
            healthy: true,
            status: "connected",
            response_time_ms: response_time,
            entity_count: entities.size
          }
        end

        response_time = ((Time.current - start_time) * 1000).round(2)

        track_health_event(:api_check, payload: {
          healthy: true,
          response_time_ms: response_time
        })

        {
          healthy: true,
          status: "connected",
          response_time_ms: response_time
        }
      end

      result
    rescue => e
      track_health_event(:api_check_failed, severity: :error, payload: {
        error: e.message,
        error_type: e.class.name,
        backtrace: e.backtrace&.first(10)
      })

      {
        healthy: false,
        status: "error",
        error: e.message,
        error_type: e.class.name
      }
    end

    def queue_health_check
      require "sidekiq/api"

      stats = Sidekiq::Stats.new
      queues = Sidekiq::Queue.all
      failed = Sidekiq::RetrySet.new

      max_queue_size = 1000
      max_failed_jobs = 100
      max_retry_jobs = 50

      queue_sizes = queues.map { |q| [ q.name, q.size ] }.to_h
      total_enqueued = queue_sizes.values.sum

      large_queues = queue_sizes.select { |_name, size| size > max_queue_size }

      healthy = total_enqueued < max_queue_size &&
               failed.size < max_failed_jobs &&
               stats.retry_size < max_retry_jobs &&
               large_queues.empty?

      alerts = []
      alerts << "QueueSizeExceeded" if total_enqueued >= max_queue_size
      alerts << "TooManyFailedJobs" if failed.size >= max_failed_jobs
      alerts << "LargeQueuesDetected" if large_queues.any?

      result = {
        healthy: healthy,
        total_enqueued: total_enqueued,
        failed_count: failed.size,
        retry_count: stats.retry_size,
        queue_sizes: queue_sizes,
        large_queues: large_queues.keys,
        processed_today: stats.processed,
        failed_today: stats.failed
      }

      track_health_event(:queue_check, payload: {
        healthy: healthy,
        total_enqueued: total_enqueued,
        failed_count: failed.size,
        retry_count: stats.retry_size,
        queue_sizes: queue_sizes,
        processed_today: stats.processed,
        failed_today: stats.failed,
        alerts: alerts.presence
      })

      result
    rescue => e
      track_health_event(:queue_check_failed, severity: :error, payload: {
        error: e.message,
        error_type: e.class.name,
        backtrace: e.backtrace&.first(10)
      })

      {
        healthy: false,
        error: e.message,
        error_type: e.class.name
      }
    end

    def full_health_check
      results = {}
      overall_healthy = true

      import_status = import_health_status
      results[:imports] = import_status
      overall_healthy &&= import_status[:overall_healthy]

      api_status = api_health_check
      results[:api] = api_status
      overall_healthy &&= api_status[:healthy]

      queue_status = queue_health_check
      results[:queues] = queue_status
      overall_healthy &&= queue_status[:healthy]

      failed_checks = []
      failed_checks << "imports" unless import_status[:overall_healthy]
      failed_checks << "api" unless api_status[:healthy]
      failed_checks << "queues" unless queue_status[:healthy]

      track_health_event(:full_check, payload: {
        healthy: overall_healthy,
        timestamp: Time.current.iso8601,
        imports_healthy: import_status[:overall_healthy],
        api_healthy: api_status[:healthy],
        queues_healthy: queue_status[:healthy],
        failed_check_count: failed_checks.size
      })

      {
        healthy: overall_healthy,
        timestamp: Time.current.iso8601,
        checks: results
      }
    end

    private

    def import_status_key(entity_type)
      "saumon_net:import_status:#{entity_type}"
    end

    def configure_saumon_net
      SaumonNet.configure do |config|
        config.base_url = Rails.application.credentials.saumon_net.base_url
        config.api_token = Rails.application.credentials.saumon_net.api_token
      end
    end
  end
end
