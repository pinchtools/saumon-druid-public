require "rails_helper"

RSpec.describe ServiceEventable do
  let(:test_service_class) do
    Class.new do
      include ServiceEventable

      def self.name
        "TestService"
      end
    end
  end
  let(:service) { test_service_class.new }

  after { Current.reset }

  describe "#track_event" do
    let(:action) { :started }

    it "creates an event with the given action" do
      event = service.track_event(action)

      expect(event.action).to eq("started")
    end

    it "sets eventable_type to service class name" do
      event = service.track_event(action)

      expect(event.eventable_type).to eq("TestService")
    end

    it "sets eventable_id to nil" do
      event = service.track_event(action)

      expect(event.eventable_id).to be_nil
    end

    it "uses 'service' as default category" do
      event = service.track_event(action)

      expect(event.category).to eq("service")
    end

    context "with custom category" do
      it "uses the provided category" do
        event = service.track_event(action, category: "import")

        expect(event.category).to eq("import")
      end
    end

    context "with payload" do
      let(:payload) { { entity_type: "stakeholders", count: 100 } }

      it "stores the payload" do
        event = service.track_event(action, payload: payload)

        expect(event.payload).to include("entity_type" => "stakeholders", "count" => 100)
      end
    end

    context "with service_context override" do
      let(:test_service_class) do
        Class.new do
          include ServiceEventable

          def self.name
            "ContextService"
          end

          private

          def service_context
            { service_version: "1.0" }
          end
        end
      end

      it "merges service_context into payload" do
        event = service.track_event(action, payload: { custom: "data" })

        expect(event.payload).to include("service_version" => "1.0", "custom" => "data")
      end
    end

    context "with severity" do
      it "defaults to info" do
        event = service.track_event(action)

        expect(event.severity).to eq("info")
      end

      it "uses provided severity" do
        event = service.track_event(action, severity: :error)

        expect(event.severity).to eq("error")
      end
    end

    context "with Current attributes set" do
      let(:current_session_id) { SecureRandom.uuid }

      before do
        Current.session_id = current_session_id
        Current.request_id = "request-def"
        Current.job_id = "job-ghi"
      end

      it "uses Current.session_id" do
        event = service.track_event(action)

        expect(event.session_id).to eq(current_session_id)
      end

      it "uses Current.request_id" do
        event = service.track_event(action)

        expect(event.request_id).to eq("request-def")
      end

      it "uses Current.job_id" do
        event = service.track_event(action)

        expect(event.job_id).to eq("job-ghi")
      end
    end

    context "with explicit session_id on service" do
      let(:service_session_id) { SecureRandom.uuid }

      before do
        Current.session_id = SecureRandom.uuid
        service.session_id = service_session_id
      end

      it "uses service session_id over Current.session_id" do
        event = service.track_event(action)

        expect(event.session_id).to eq(service_session_id)
      end
    end
  end
end
