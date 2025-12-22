# frozen_string_literal: true

module Agents::RubyLlmRescuable
  extend ActiveSupport::Concern

  included do
    include ActiveSupport::Rescuable

    # RubyLLM exception handlers - order matters (base class first, specific last)
    # rescue_from matches in reverse order (last declared = first matched)
    rescue_from RubyLLM::Error, with: :handle_ruby_llm_error
    rescue_from RubyLLM::ModelNotFoundError, with: :handle_model_not_found_error
    rescue_from RubyLLM::BadRequestError, with: :handle_bad_request_error
    rescue_from RubyLLM::ServiceUnavailableError, with: :handle_service_unavailable_error
    rescue_from RubyLLM::RateLimitError, with: :handle_rate_limit_error
    rescue_from RubyLLM::PaymentRequiredError, with: :handle_payment_required_error
    rescue_from RubyLLM::UnauthorizedError, with: :handle_unauthorized_error
  end

  private

  def handle_unauthorized_error(exception)
    track_llm_error(exception, "unauthorized")
    raise exception
  end

  def handle_payment_required_error(exception)
    track_llm_error(exception, "payment_required")
    raise exception
  end

  def handle_rate_limit_error(exception)
    track_llm_error(exception, "rate_limit")
    raise exception
  end

  def handle_service_unavailable_error(exception)
    track_llm_error(exception, "service_unavailable")
    raise exception
  end

  def handle_bad_request_error(exception)
    track_llm_error(exception, "bad_request")
    raise exception
  end

  def handle_model_not_found_error(exception)
    track_llm_error(exception, "model_not_found")
    raise exception
  end

  def handle_ruby_llm_error(exception)
    track_llm_error(exception, "api_error")
    raise exception
  end

  def track_llm_error(exception, error_type)
    Event.create!(
      category: "llm",
      action: "error",
      severity: "error",
      payload: {
        agent: agent_name,
        agent_version: version,
        model: @current_model&.external_id,
        error_type: error_type,
        error_class: exception.class.name,
        error_message: exception.message
      },
      session_id: Current.session_id,
      request_id: Current.request_id,
      job_id: Current.job_id
    )
  end

  def with_llm_error_handling
    yield
  rescue => e
    rescue_with_handler(e) || raise
  end
end
