# frozen_string_literal: true

# Service for reporting and querying events
# Used by rake tasks and console helpers
class Event::ReporterService
  def initialize(output: $stdout)
    @output = output
  end

  def report_conversation(conversation_id, limit: 100)
    events = Event.for_conversation(conversation_id).recent.limit(limit)

    if events.empty?
      print_message "No events found for conversation #{conversation_id}"
      return
    end

    print_header "Events for Conversation #{conversation_id}"
    Event.pretty_print(events, output: @output)
    print_summary(events)
  end

  def report_message(message_id, limit: 100)
    events = Event.for_message(message_id).recent.limit(limit)

    if events.empty?
      print_message "No events found for message #{message_id}"
      return
    end

    print_header "Events for Message #{message_id}"
    Event.pretty_print(events, output: @output)
    print_summary(events)
  end

  def report_errors(limit: 50)
    events = Event.errors.recent.limit(limit)

    if events.empty?
      print_message "No error events found"
      return
    end

    print_header "Recent Error Events (last #{limit})"
    Event.pretty_print(events, output: @output)
    @output.puts "\nTotal errors: #{events.size}"
  end

  def report_category(category, limit: 100)
    events = Event.by_category(category).recent.limit(limit)

    if events.empty?
      print_message "No events found for category '#{category}'"
      return
    end

    print_header "Events for Category '#{category}'"
    Event.pretty_print(events, output: @output)
    @output.puts "\nTotal events: #{events.size}"
  end

  def report_stats
    total_count = Event.count

    print_header "Event Statistics"

    @output.puts "Total events: #{total_count}"
    @output.puts

    print_severity_stats(total_count)
    print_category_stats(total_count)
    print_activity_stats
    print_error_rate
  end

  def list_categories
    @output.puts "\nAvailable categories:"
    Event.distinct.pluck(:category).sort.each { |cat| @output.puts "  - #{cat}" }
  end

  private

  def print_header(title)
    @output.puts "\n" + "=" * 80
    @output.puts title
    @output.puts "=" * 80 + "\n"
  end

  def print_message(message)
    @output.puts message
  end

  def print_summary(events)
    @output.puts "\nTotal events: #{events.size}"
    @output.puts "Errors: #{events.errors.count}"
    @output.puts "Warnings: #{events.warnings.count}"
  end

  def print_severity_stats(total_count)
    @output.puts "By Severity:"
    Event.group(:severity).count.sort.each do |severity, count|
      percentage = (count * 100.0 / total_count).round(2)
      @output.puts "  #{severity.ljust(10)} #{count.to_s.rjust(8)} (#{percentage}%)"
    end
    @output.puts
  end

  def print_category_stats(total_count)
    @output.puts "By Category (top 10):"
    Event.group(:category).count.sort_by { |_, count| -count }.first(10).each do |category, count|
      percentage = (count * 100.0 / total_count).round(2)
      @output.puts "  #{category.ljust(20)} #{count.to_s.rjust(8)} (#{percentage}%)"
    end
    @output.puts
  end

  def print_activity_stats
    @output.puts "Recent Activity:"
    @output.puts "  Last hour:     #{Event.since(1.hour.ago).count}"
    @output.puts "  Last 24 hours: #{Event.since(24.hours.ago).count}"
    @output.puts "  Last 7 days:   #{Event.since(7.days.ago).count}"
    @output.puts
  end

  def print_error_rate
    @output.puts "Error Rate (last 24h):"
    last_24h = Event.since(24.hours.ago)
    error_count = last_24h.errors.count
    total_24h = last_24h.count

    if total_24h > 0
      error_rate = (error_count * 100.0 / total_24h).round(2)
      @output.puts "  #{error_count} errors out of #{total_24h} events (#{error_rate}%)"
    else
      @output.puts "  No events in the last 24 hours"
    end
  end
end
