# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Event::Debuggable do
  let(:conversation_id) { "conv-123" }
  let(:message_id) { "msg-456" }
  let(:trace_id) { "trace-789" }

  before do
    # Create test events with different contexts
    create(:event, category: "llm", action: "request",
           payload: { conversation_id: conversation_id, message_id: message_id })
    create(:event, category: "llm", action: "response",
           payload: { conversation_id: conversation_id, message_id: message_id })
    create(:event, category: "agent", action: "started",
           payload: { conversation_id: conversation_id, message_id: "other-msg" })
    create(:event, category: "agent", action: "completed",
           payload: { trace_id: trace_id })
  end

  describe '.for_conversation' do
    it 'returns events for the specified conversation' do
      events = Event.for_conversation(conversation_id)

      expect(events.count).to eq(3)
      expect(events.pluck(:category)).to contain_exactly("llm", "llm", "agent")
    end

    it 'returns empty relation for non-existent conversation' do
      events = Event.for_conversation("non-existent")

      expect(events.count).to eq(0)
    end

    it 'handles integer conversation IDs' do
      numeric_id = 999
      create(:event, category: "test", action: "test",
             payload: { conversation_id: numeric_id })

      events = Event.for_conversation(numeric_id)

      expect(events.count).to eq(1)
    end
  end

  describe '.for_message' do
    it 'returns events for the specified message' do
      events = Event.for_message(message_id)

      expect(events.count).to eq(2)
      expect(events.pluck(:action)).to contain_exactly("request", "response")
    end

    it 'returns empty relation for non-existent message' do
      events = Event.for_message("non-existent")

      expect(events.count).to eq(0)
    end
  end

  describe '.with_trace' do
    it 'returns events with the specified trace ID' do
      events = Event.with_trace(trace_id)

      expect(events.count).to eq(1)
      expect(events.first.action).to eq("completed")
    end

    it 'returns empty relation for non-existent trace' do
      events = Event.with_trace("non-existent")

      expect(events.count).to eq(0)
    end
  end

  describe '#conversation_id' do
    it 'extracts conversation_id from payload' do
      event = Event.for_conversation(conversation_id).first

      expect(event.conversation_id).to eq(conversation_id)
    end

    it 'returns nil when conversation_id not in payload' do
      event = Event.with_trace(trace_id).first

      expect(event.conversation_id).to be_nil
    end
  end

  describe '#message_id' do
    it 'extracts message_id from payload' do
      event = Event.for_message(message_id).first

      expect(event.message_id).to eq(message_id)
    end

    it 'returns nil when message_id not in payload' do
      event = Event.with_trace(trace_id).first

      expect(event.message_id).to be_nil
    end
  end

  describe '#trace_id' do
    it 'extracts trace_id from payload' do
      event = Event.with_trace(trace_id).first

      expect(event.trace_id).to eq(trace_id)
    end

    it 'returns nil when trace_id not in payload' do
      event = Event.for_conversation(conversation_id).first

      expect(event.trace_id).to be_nil
    end
  end

  describe '.debug_conversation' do
    it 'returns recent events for conversation with limit' do
      # Create more events
      20.times do |i|
        create(:event, category: "test", action: "test_#{i}",
               payload: { conversation_id: conversation_id })
      end

      # Use positional argument for limit (scopes don't use keyword args)
      events = Event.debug_conversation(conversation_id, 10)

      # Total events for conversation is 3 (from before block) + 20 = 23
      # With limit 10, should return 10
      expect(events.size).to eq(10)
      # Check they're in reverse chronological order
      timestamps = events.map(&:created_at)
      expect(timestamps).to eq(timestamps.sort.reverse)
    end

    it 'uses default limit of 100' do
      events = Event.debug_conversation(conversation_id)

      expect(events.limit_value).to eq(100)
    end
  end

  describe '.debug_message' do
    it 'returns recent events for message with limit' do
      # Use positional argument for limit
      events = Event.debug_message(message_id, 1)

      expect(events.count).to eq(1)
    end

    it 'uses default limit of 100' do
      events = Event.debug_message(message_id)

      expect(events.limit_value).to eq(100)
    end
  end

  describe '.debug_trace' do
    it 'returns recent events for trace with limit' do
      events = Event.debug_trace(trace_id)

      expect(events.count).to eq(1)
    end

    it 'uses default limit of 100' do
      events = Event.debug_trace(trace_id)

      expect(events.limit_value).to eq(100)
    end
  end

  describe '.pretty_print' do
    it 'outputs formatted event information' do
      events = Event.for_message(message_id)
      output = StringIO.new

      # Capture output
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      Event.pretty_print(events)

      output.rewind
      result = output.read

      expect(result).to include("llm.request")
      expect(result).to include("llm.response")
      expect(result).to include(message_id)
      expect(result).to include(conversation_id)
    end

    it 'returns nil' do
      events = Event.for_message(message_id)

      result = Event.pretty_print(events)

      expect(result).to be_nil
    end
  end
end
