require "rails_helper"

RSpec.describe Event, type: :model do
  describe "validations" do
    it { should validate_presence_of(:category) }
    it { should validate_presence_of(:action) }
    it { should validate_inclusion_of(:severity).in_array(%w[debug info warn error]) }
  end

  describe "associations" do
    it { should belong_to(:eventable).optional }
    it { should belong_to(:actor).optional }
  end

  describe "scopes" do
    let!(:error_event) { create(:event, severity: "error", created_at: 1.hour.ago) }
    let!(:warn_event) { create(:event, severity: "warn", created_at: 2.hours.ago) }
    let!(:info_event) { create(:event, severity: "info", created_at: 3.hours.ago) }

    describe ".recent" do
      it "orders by created_at descending" do
        expect(Event.recent.first).to eq(error_event)
        expect(Event.recent.last).to eq(info_event)
      end
    end

    describe ".by_category" do
      let!(:import_event) { create(:event, category: "import") }
      let!(:health_event) { create(:event, category: "health") }

      it "filters by category" do
        expect(Event.by_category("import")).to include(import_event)
        expect(Event.by_category("import")).not_to include(health_event)
      end
    end

    describe ".by_action" do
      let!(:started_event) { create(:event, action: "started") }
      let!(:completed_event) { create(:event, action: "completed") }

      it "filters by action" do
        expect(Event.by_action("started")).to include(started_event)
        expect(Event.by_action("started")).not_to include(completed_event)
      end
    end

    describe ".errors" do
      it "returns only error severity events" do
        expect(Event.errors).to include(error_event)
        expect(Event.errors).not_to include(warn_event, info_event)
      end
    end

    describe ".warnings" do
      it "returns only warn severity events" do
        expect(Event.warnings).to include(warn_event)
        expect(Event.warnings).not_to include(error_event, info_event)
      end
    end

    describe ".in_session" do
      let(:session_id) { SecureRandom.uuid }
      let!(:session_event) { create(:event, session_id: session_id) }

      it "filters by session_id" do
        expect(Event.in_session(session_id)).to include(session_event)
        expect(Event.in_session(session_id)).not_to include(error_event)
      end
    end

    describe ".for_request" do
      let(:request_id) { "req-123" }
      let!(:request_event) { create(:event, request_id: request_id) }

      it "filters by request_id" do
        expect(Event.for_request(request_id)).to include(request_event)
        expect(Event.for_request(request_id)).not_to include(error_event)
      end
    end

    describe ".since" do
      let(:date_time) { 90.minutes.ago }
      it "returns events since the given time" do
        expect(Event.since(date_time)).to include(error_event)
        expect(Event.since(date_time)).not_to include(warn_event, info_event)
      end
    end

    describe ".until" do
      let(:date_time) { 90.minutes.ago }
      it "returns events until the given time" do
        expect(Event.until(date_time)).to include(warn_event, info_event)
        expect(Event.until(date_time)).not_to include(error_event)
      end
    end
  end

  describe "#full_action" do
    let(:event) { build(:event, category: "import", action: "completed") }

    it "returns category.action format" do
      expect(event.full_action).to eq("import.completed")
    end
  end

  describe "after_create_commit callback" do
    let(:observer) { instance_double(Event::Observer) }
    before do
      allow(Event::Observer).to receive(:new).and_return(observer)
      allow(observer).to receive(:observe)
    end

    it "notifies the observer" do
      create(:event)

      expect(observer).to have_received(:observe)
    end
  end
end
