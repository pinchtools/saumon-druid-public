class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  # Basic health check endpoint
  def show
    render json: { status: "ok", timestamp: Time.current.iso8601 }
  end


  def saumon_net
    health_status = SaumonNet::HealthMonitoringService.full_health_check

    status_code = health_status[:healthy] ? :ok : :service_unavailable

    render json: health_status, status: status_code
  end

  def imports
    import_status = SaumonNet::HealthMonitoringService.import_health_status

    status_code = import_status[:overall_healthy] ? :ok : :service_unavailable

    render json: import_status, status: status_code
  end

  def api
    api_status = SaumonNet::HealthMonitoringService.api_health_check

    status_code = api_status[:healthy] ? :ok : :service_unavailable

    render json: api_status, status: status_code
  end

  def queues
    queue_status = SaumonNet::HealthMonitoringService.queue_health_check

    status_code = queue_status[:healthy] ? :ok : :service_unavailable

    render json: queue_status, status: status_code
  end
end
