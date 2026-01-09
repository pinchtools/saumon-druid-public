# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Event::ReporterService do
  let(:output) { StringIO.new }
  let(:reporter) { described_class.new(output: output) }
  let(:conversation_id) { "conv-123" }
  let(:message_id) { "msg-456" }

  before do
    create(:event, category: "llm", action: "request",
           payload: { conversation_id: conversation_id, message_id: message_id })
    create(:event, category: "llm", action: "response",
           payload: { conversation_id: conversation_id, message_id: message_id })
    create(:event, category: "agent", action: "started", severity: "error",
           payload: { conversation_id: conversation_id })
  end

  describe '#report_conversation' do
    it 'outputs conversation events' do
      reporter.report_conversation(conversation_id)

      output.rewind
      result = output.read

      expect(result).to include("Events for Conversation #{conversation_id}")
      # Pretty print shows timestamps and categories
      expect(result).to match(/llm\.request/)
      expect(result).to match(/llm\.response/)
      expect(result).to include("Total events: 3")
      expect(result).to include("Errors: 1")
    end

    it 'shows message when no events found' do
      reporter.report_conversation("non-existent")

      output.rewind
      result = output.read

      expect(result).to include("No events found for conversation non-existent")
    end

    it 'respects limit parameter' do
      10.times { |i| create(:event, category: "test", action: "test_#{i}",
                            payload: { conversation_id: conversation_id }) }

      reporter.report_conversation(conversation_id, limit: 5)

      output.rewind
      result = output.read

      expect(result).to include("Total events: 5")
    end
  end

  describe '#report_message' do
    it 'outputs message events' do
      reporter.report_message(message_id)

      output.rewind
      result = output.read

      expect(result).to include("Events for Message #{message_id}")
      expect(result).to match(/llm\.request/)
      expect(result).to match(/llm\.response/)
      expect(result).to include("Total events: 2")
    end

    it 'shows message when no events found' do
      reporter.report_message("non-existent")

      output.rewind
      result = output.read

      expect(result).to include("No events found for message non-existent")
    end
  end

  describe '#report_errors' do
    it 'outputs error events' do
      reporter.report_errors

      output.rewind
      result = output.read

      expect(result).to include("Recent Error Events")
      expect(result).to match(/agent\.started/)
      expect(result).to include("Total errors: 1")
    end

    it 'shows message when no errors found' do
      Event.errors.delete_all

      reporter.report_errors

      output.rewind
      result = output.read

      expect(result).to include("No error events found")
    end

    it 'respects limit parameter' do
      60.times { create(:event, category: "test", action: "error", severity: "error") }

      reporter.report_errors(limit: 50)

      output.rewind
      result = output.read

      expect(result).to include("Total errors: 50")
    end
  end

  describe '#report_category' do
    it 'outputs events for specified category' do
      reporter.report_category("llm")

      output.rewind
      result = output.read

      expect(result).to include("Events for Category 'llm'")
      expect(result).to match(/llm\.request/)
      expect(result).to match(/llm\.response/)
      expect(result).to include("Total events: 2")
    end

    it 'shows message when no events found' do
      reporter.report_category("nonexistent")

      output.rewind
      result = output.read

      expect(result).to include("No events found for category 'nonexistent'")
    end
  end

  describe '#report_stats' do
    before do
      # Create diverse events for stats
      create(:event, category: "system", action: "test", severity: "info")
      create(:event, category: "system", action: "test", severity: "warn")
      create(:event, category: "data", action: "test", severity: "debug")
    end

    it 'outputs overall statistics' do
      reporter.report_stats

      output.rewind
      result = output.read

      expect(result).to include("Event Statistics")
      expect(result).to include("Total events:")
      expect(result).to include("By Severity:")
      expect(result).to include("By Category")
      expect(result).to include("Recent Activity:")
      expect(result).to include("Error Rate")
    end

    it 'includes severity breakdown' do
      reporter.report_stats

      output.rewind
      result = output.read

      expect(result).to match(/info.*\d+/)
      expect(result).to match(/error.*\d+/)
      expect(result).to match(/warn.*\d+/)
    end

    it 'includes category breakdown' do
      reporter.report_stats

      output.rewind
      result = output.read

      expect(result).to include("llm")
      expect(result).to include("agent")
      expect(result).to include("system")
    end

    it 'includes time-based activity' do
      reporter.report_stats

      output.rewind
      result = output.read

      expect(result).to include("Last hour:")
      expect(result).to include("Last 24 hours:")
      expect(result).to include("Last 7 days:")
    end

    it 'calculates error rate' do
      reporter.report_stats

      output.rewind
      result = output.read

      expect(result).to match(/\d+ errors out of \d+ events/)
    end
  end

  describe '#list_categories' do
    it 'lists all available categories' do
      reporter.list_categories

      output.rewind
      result = output.read

      expect(result).to include("Available categories:")
      expect(result).to include("agent")
      expect(result).to include("llm")
    end

    it 'lists categories alphabetically' do
      create(:event, category: "zebra", action: "test")
      create(:event, category: "alpha", action: "test")

      reporter.list_categories

      output.rewind
      result = output.read
      categories = result.scan(/- (\w+)/).flatten

      expect(categories).to eq(categories.sort)
    end
  end
end
