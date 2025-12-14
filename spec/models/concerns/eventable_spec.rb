require "rails_helper"

RSpec.describe Eventable do
  before(:all) do
    @test_class = Class.new(ApplicationRecord) do
      self.table_name = "an_stakeholders"
      include Eventable

      def self.name
        "TestEventableModel"
      end
    end

    @an_test_class = Class.new(ApplicationRecord) do
      self.table_name = "an_stakeholders"
      include Eventable

      def self.name
        "An::TestModel"
      end
    end
  end

  let(:model) { @test_class.create!(uid: SecureRandom.uuid, first_name: "Test", last_name: "User") }
  let(:an_model) { @an_test_class.create!(uid: SecureRandom.uuid, first_name: "An", last_name: "Model") }

  after { Current.reset }

  describe "associations" do
    it "has many events as eventable" do
      event = create(:event, eventable: model)

      expect(model.events).to include(event)
    end
  end

  describe "#track_event" do
    let(:action) { :imported }

    it "creates an event with the given action" do
      event = model.track_event(action)

      expect(event.action).to eq("imported")
    end

    it "sets eventable to self" do
      event = model.track_event(action)

      expect(event.eventable_type).to eq("TestEventableModel")
      expect(event.eventable_id).to eq(model.id)
    end

    it "uses default category based on class name" do
      event = model.track_event(action)

      expect(event.category).to eq("application")
    end

    context "with An:: namespaced class" do
      it "uses 'data' as default category" do
        event = an_model.track_event(action)

        expect(event.category).to eq("data")
      end
    end

    context "with custom category" do
      it "uses the provided category" do
        event = model.track_event(action, category: "custom")

        expect(event.category).to eq("custom")
      end
    end

    context "with payload" do
      let(:payload) { { source: "saumon_net", count: 10 } }

      it "stores the payload" do
        event = model.track_event(action, payload: payload)

        expect(event.payload).to eq("source" => "saumon_net", "count" => 10)
      end
    end

    context "with severity" do
      it "defaults to info" do
        event = model.track_event(action)

        expect(event.severity).to eq("info")
      end

      it "uses provided severity" do
        event = model.track_event(action, severity: :error)

        expect(event.severity).to eq("error")
      end
    end

    context "with Current attributes set" do
      let(:current_session_id) { SecureRandom.uuid }

      before do
        Current.session_id = current_session_id
        Current.request_id = "request-456"
        Current.job_id = "job-789"
      end

      it "uses Current.session_id" do
        event = model.track_event(action)

        expect(event.session_id).to eq(current_session_id)
      end

      it "uses Current.request_id" do
        event = model.track_event(action)

        expect(event.request_id).to eq("request-456")
      end

      it "uses Current.job_id" do
        event = model.track_event(action)

        expect(event.job_id).to eq("job-789")
      end
    end

    context "with explicit session_id" do
      let(:explicit_session_id) { SecureRandom.uuid }

      before { Current.session_id = SecureRandom.uuid }

      it "overrides Current.session_id" do
        event = model.track_event(action, session_id: explicit_session_id)

        expect(event.session_id).to eq(explicit_session_id)
      end
    end
  end
end
