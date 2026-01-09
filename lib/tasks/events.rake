# frozen_string_literal: true

namespace :events do
  desc "Show events for a conversation"
  task :conversation, [ :conversation_id ] => :environment do |_t, args|
    if args[:conversation_id].blank?
      puts "Usage: rake events:conversation[CONVERSATION_ID]"
      puts "Example: rake events:conversation[123]"
      exit 1
    end

    Event::ReporterService.new.report_conversation(args[:conversation_id])
  end

  desc "Show events for a message"
  task :message, [ :message_id ] => :environment do |_t, args|
    if args[:message_id].blank?
      puts "Usage: rake events:message[MESSAGE_ID]"
      puts "Example: rake events:message[456]"
      exit 1
    end

    Event::ReporterService.new.report_message(args[:message_id])
  end

  desc "Show recent error events"
  task errors: :environment do
    Event::ReporterService.new.report_errors
  end

  desc "Show events for a specific category"
  task :category, [ :category ] => :environment do |_t, args|
    reporter = Event::ReporterService.new

    if args[:category].blank?
      puts "Usage: rake events:category[CATEGORY]"
      puts "Example: rake events:category[llm]"
      reporter.list_categories
      exit 1
    end

    reporter.report_category(args[:category])
  end

  desc "Show event statistics"
  task stats: :environment do
    Event::ReporterService.new.report_stats
  end
end
