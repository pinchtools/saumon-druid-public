require 'rails_helper'

RSpec.describe Agents::RubyLlmRescuable do
  let(:test_class) do
    Class.new do
      include Agents::RubyLlmRescuable

      attr_accessor :current_model

      def agent_name
        "test_agent"
      end

      def version
        1
      end

      def risky_operation
        with_llm_error_handling do
          yield
        end
      end
    end
  end

  subject(:instance) { test_class.new }

  let(:mock_response) do
    instance_double(Faraday::Response, body: { "error" => { "message" => "test error" } })
  end

  before do
    instance.current_model = instance_double("LlmModel", external_id: "gpt-4")
  end

  after { Current.reset }

  describe 'rescue_from handlers' do
    shared_examples 'tracks error and re-raises' do |exception_class, error_type, with_response|
      it "tracks #{exception_class} as #{error_type} and re-raises" do
        params = (with_response) ? [ mock_response, error_type ] : [ error_type ]
        exception = exception_class.new(*params)

        expect {
          instance.risky_operation { raise exception }
        }.to raise_error(exception_class)
          .and change(Event, :count).by(1)

        event = Event.find_by_category("llm")
        expect(event.action).to eq("error")
        expect(event.severity).to eq("error")
        expect(event.payload["error_type"]).to eq(error_type)
        expect(event.payload["error_class"]).to eq(exception_class.name)
        expect(event.payload["error_message"]).to include(error_type)
        expect(event.payload["agent"]).to eq("test_agent")
        expect(event.payload["agent_version"]).to eq(1)
        expect(event.payload["model"]).to eq("gpt-4")
      end
    end

    include_examples 'tracks error and re-raises', RubyLLM::UnauthorizedError, "unauthorized", true
    include_examples 'tracks error and re-raises', RubyLLM::PaymentRequiredError, "payment_required", true
    include_examples 'tracks error and re-raises', RubyLLM::RateLimitError, "rate_limit", true
    include_examples 'tracks error and re-raises', RubyLLM::ServiceUnavailableError, "service_unavailable", true
    include_examples 'tracks error and re-raises', RubyLLM::BadRequestError, "bad_request", true
    include_examples 'tracks error and re-raises', RubyLLM::ModelNotFoundError, "model_not_found", false
    include_examples 'tracks error and re-raises', RubyLLM::Error, "api_error", true
  end

  describe '#with_llm_error_handling' do
    it 'returns block result on success' do
      result = instance.risky_operation { "success" }
      expect(result).to eq("success")
    end

    it 're-raises unhandled exceptions' do
      expect {
        instance.risky_operation { raise StandardError, "unhandled" }
      }.to raise_error(StandardError, "unhandled")
    end

    it 'captures Current context in events' do
      Current.session_id = SecureRandom.uuid
      Current.request_id = SecureRandom.uuid
      Current.job_id = SecureRandom.uuid

      expect {
        instance.risky_operation { raise RubyLLM::Error.new(mock_response) }
      }.to raise_error(RubyLLM::Error)

      event = Event.find_by_category("llm")
      expect(event.session_id).to eq(Current.session_id)
      expect(event.request_id).to eq(Current.request_id)
      expect(event.job_id).to eq(Current.job_id)
    end
  end
end
