require "rails_helper"

RSpec.describe ApplicationController, type: :request do
  describe "#set_current_request_id" do
    module RequestIdCapture
      mattr_accessor :captured_ids
      self.captured_ids = []

      def capture_current_request_id
        RequestIdCapture.captured_ids << Current.request_id
      end
    end

    before(:all) do
      HealthController.include(RequestIdCapture)
      HealthController.after_action(:capture_current_request_id)
    end

    after(:all) do
      HealthController.skip_callback(:process_action, :after, :capture_current_request_id)
    end

    before do
      RequestIdCapture.captured_ids.clear
    end

    it "sets Current.request_id to the request's X-Request-Id header value" do
      expected_request_id = "test-request-id-abc123"

      get health_check_path, headers: { "X-Request-Id" => expected_request_id }

      expect(response).to have_http_status(:ok)
      expect(RequestIdCapture.captured_ids.last).to eq(expected_request_id)
    end

    it "sets Current.request_id when X-Request-Id header is not provided" do
      get health_check_path

      expect(response).to have_http_status(:ok)
      expect(RequestIdCapture.captured_ids.last).to be_present
    end

    it "sets a unique Current.request_id for each request" do
      get health_check_path
      first_request_id = RequestIdCapture.captured_ids.last

      get health_check_path
      second_request_id = RequestIdCapture.captured_ids.last

      expect(first_request_id).not_to eq(second_request_id)
    end
  end
end
