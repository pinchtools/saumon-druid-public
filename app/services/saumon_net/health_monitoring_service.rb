module SaumonNet
  class HealthMonitoringService
    include ActiveSupport::Benchmarkable

    class << self
      # Track last successful import for each entity type
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

        # Send success metrics to New Relic
        if stats && defined?(NewRelic::Agent)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Import/#{entity_type}/LastSuccess", Time.current.to_i)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Import/#{entity_type}/LastSuccessRate", stats.success_rate)

          NewRelic::Agent.add_custom_attributes({
            "saumon_net.import.entity_type" => entity_type,
            "saumon_net.import.processed" => stats.processed,
            "saumon_net.import.success_rate" => stats.success_rate
          })
        end
      end

      # Get last successful import status for entity type
      def last_import_status(entity_type)
        Rails.cache.read(import_status_key(entity_type))
      end

      # Check if imports are healthy (recent successful imports)
      def import_health_status
        entity_types = %w[organe pays] # Add more entity types as they're implemented
        results = {}
        healthy_count = 0

        entity_types.each do |entity_type|
          last_import = last_import_status(entity_type)

          if last_import.nil?
            results[entity_type] = { status: "never_imported", healthy: false }

            # Record metric for never imported entity
            if defined?(NewRelic::Agent)
              NewRelic::Agent.record_metric("Custom/SaumonNet/Health/#{entity_type}/NeverImported", 1)
            end
          else
            last_time = Time.parse(last_import[:timestamp])
            age_hours = (Time.current - last_time) / 1.hour

            # Consider healthy if imported within last 24 hours
            healthy = age_hours < 24
            healthy_count += 1 if healthy

            results[entity_type] = {
              status: healthy ? "healthy" : "stale",
              healthy: healthy,
              last_import: last_import[:timestamp],
              age_hours: age_hours.round(2),
              stats: last_import[:stats]
            }

            # Record metrics for import staleness
            if defined?(NewRelic::Agent)
              NewRelic::Agent.record_metric("Custom/SaumonNet/Health/#{entity_type}/AgeHours", age_hours)
              NewRelic::Agent.record_metric("Custom/SaumonNet/Health/#{entity_type}/Healthy", healthy ? 1 : 0)
            end
          end
        end

        overall_healthy = results.values.all? { |r| r[:healthy] }

        # Record overall health metrics
        if defined?(NewRelic::Agent)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Health/Overall/Healthy", overall_healthy ? 1 : 0)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Health/Overall/HealthyEntityCount", healthy_count)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Health/Overall/TotalEntityCount", entity_types.size)
        end

        {
          overall_healthy: overall_healthy,
          entity_types: results
        }
      end

      # Check API connectivity
      def api_health_check
        start_time = Time.current

        result = benchmark "SaumonNet API health check" do
          configure_saumon_net

          # Perform a simple API call to check connectivity
          SaumonNet::Entity.list_all(type: "organe", limit: 1) do |entities|
            response_time = ((Time.current - start_time) * 1000).round(2)

            # Record API health metrics
            if defined?(NewRelic::Agent)
              NewRelic::Agent.record_metric("Custom/SaumonNet/API/ResponseTime", response_time)
              NewRelic::Agent.record_metric("Custom/SaumonNet/API/Healthy", 1)
              NewRelic::Agent.record_metric("Custom/SaumonNet/API/ConnectivityCheck", 1)
            end

            return {
              healthy: true,
              status: "connected",
              response_time_ms: response_time,
              entity_count: entities.size
            }
          end

          # If we get here without an exception, API is healthy
          response_time = ((Time.current - start_time) * 1000).round(2)

          if defined?(NewRelic::Agent)
            NewRelic::Agent.record_metric("Custom/SaumonNet/API/ResponseTime", response_time)
            NewRelic::Agent.record_metric("Custom/SaumonNet/API/Healthy", 1)
          end

          {
            healthy: true,
            status: "connected",
            response_time_ms: response_time
          }
        end

        result
      rescue => e
        Rails.logger.error "SaumonNet API health check failed", component: SaumonNet::COMPONENT, error: e.message

        # Record API failure metrics
        if defined?(NewRelic::Agent)
          NewRelic::Agent.record_metric("Custom/SaumonNet/API/Healthy", 0)
          NewRelic::Agent.record_metric("Custom/SaumonNet/API/Errors", 1)
          NewRelic::Agent.notice_error(e, custom_params: {
            health_check: "api_connectivity",
            component: "saumon_net_api"
          })
        end

        {
          healthy: false,
          status: "error",
          error: e.message,
          error_type: e.class.name
        }
      end

      # Check Sidekiq queue health
      def queue_health_check
        require "sidekiq/api"

        stats = Sidekiq::Stats.new
        queues = Sidekiq::Queue.all
        failed = Sidekiq::RetrySet.new

        # Define thresholds
        max_queue_size = 1000
        max_failed_jobs = 100
        max_retry_jobs = 50

        queue_sizes = queues.map { |q| [ q.name, q.size ] }.to_h
        total_enqueued = queue_sizes.values.sum

        # Check if any individual queue is too large
        large_queues = queue_sizes.select { |name, size| size > max_queue_size }

        healthy = total_enqueued < max_queue_size &&
                 failed.size < max_failed_jobs &&
                 stats.retry_size < max_retry_jobs &&
                 large_queues.empty?

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

        # Record Sidekiq health metrics
        if defined?(NewRelic::Agent)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Healthy", healthy ? 1 : 0)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/TotalEnqueued", total_enqueued)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/FailedCount", failed.size)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/RetryCount", stats.retry_size)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/ProcessedToday", stats.processed)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/FailedToday", stats.failed)

          # Record individual queue sizes
          queue_sizes.each do |queue_name, size|
            NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Queue/#{queue_name}/Size", size)
          end

          # Record threshold violations
          if total_enqueued >= max_queue_size
            NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Alerts/QueueSizeExceeded", 1)
          end

          if failed.size >= max_failed_jobs
            NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Alerts/TooManyFailedJobs", 1)
          end

          if large_queues.any?
            NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Alerts/LargeQueuesDetected", large_queues.size)
          end
        end

        result
      rescue => e
        Rails.logger.error "Sidekiq health check failed", component: SaumonNet::COMPONENT, error: e.message

        # Record queue check failure
        if defined?(NewRelic::Agent)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Sidekiq/Healthy", 0)
          NewRelic::Agent.notice_error(e, custom_params: {
            health_check: "queue_monitoring",
            component: "sidekiq_monitoring"
          })
        end

        {
          healthy: false,
          error: e.message,
          error_type: e.class.name
        }
      end

      # Comprehensive health check
      def full_health_check
        results = {}
        overall_healthy = true

        # Start New Relic transaction
        if defined?(NewRelic::Agent)
          NewRelic::Agent.add_custom_attributes({
            "saumon_net.health_check.timestamp" => Time.current.iso8601
          })
        end

        # Check import status
        import_status = import_health_status
        results[:imports] = import_status
        overall_healthy &&= import_status[:overall_healthy]

        # Check API connectivity
        api_status = api_health_check
        results[:api] = api_status
        overall_healthy &&= api_status[:healthy]

        # Check queue health
        queue_status = queue_health_check
        results[:queues] = queue_status
        overall_healthy &&= queue_status[:healthy]

        # Record comprehensive health metrics
        if defined?(NewRelic::Agent)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/Overall", overall_healthy ? 1 : 0)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/ImportsHealthy", import_status[:overall_healthy] ? 1 : 0)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/APIHealthy", api_status[:healthy] ? 1 : 0)
          NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/QueuesHealthy", queue_status[:healthy] ? 1 : 0)

          NewRelic::Agent.add_custom_attributes({
            "saumon_net.health.overall" => overall_healthy,
            "saumon_net.health.imports" => import_status[:overall_healthy],
            "saumon_net.health.api" => api_status[:healthy],
            "saumon_net.health.queues" => queue_status[:healthy]
          })

          # Count failed checks
          failed_checks = []
          failed_checks << "imports" unless import_status[:overall_healthy]
          failed_checks << "api" unless api_status[:healthy]
          failed_checks << "queues" unless queue_status[:healthy]

          NewRelic::Agent.record_metric("Custom/SaumonNet/Health/FullCheck/FailedCheckCount", failed_checks.size)
        end

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
end
