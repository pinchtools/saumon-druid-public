module DateFilterable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where.not(start_date: nil).and(where(end_date: nil)) }
    scope :past, -> { where.not(start_date: nil).where.not(end_date: nil) }

    # Active at any point during period (year/month/day)
    # A record is considered active during a period if:
    # - Its start_date is before or on the period end
    # - Its end_date is either NULL (still active) or after or on the period start
    scope :date_eq, ->(period) {
      range = parse_date_period(period)
      where("#{table_name}.start_date <= ?", range[:end])
        .where("#{table_name}.end_date IS NULL OR #{table_name}.end_date >= ?", range[:start])
    }

    scope :date_before, ->(date) {
      parsed = date.is_a?(Date) ? date : Date.parse(date.to_s)
      where.not(end_date: nil).where("#{table_name}.end_date < ?", parsed)
    }

    scope :date_after, ->(date) {
      parsed = date.is_a?(Date) ? date : Date.parse(date.to_s)
      where("#{table_name}.start_date > ?", parsed)
    }

    scope :date_between, ->(start_date, end_date) {
      range_start = start_date.is_a?(Date) ? start_date : Date.parse(start_date.to_s)
      range_end = end_date.is_a?(Date) ? end_date : Date.parse(end_date.to_s)
      where("#{table_name}.start_date <= ?", range_end)
        .where("#{table_name}.end_date IS NULL OR #{table_name}.end_date >= ?", range_start)
    }
  end

  class_methods do
    # Parses flexible date formats to a range
    # "2024" → { start: 2024-01-01, end: 2024-12-31 }
    # "2024-06" → { start: 2024-06-01, end: 2024-06-30 }
    # "2024-06-15" → { start: 2024-06-15, end: 2024-06-15 }
    def parse_date_period(value)
      case value.to_s
      when /\A(\d{4})\z/ # Year only
        year = ::Regexp.last_match(1).to_i
        { start: Date.new(year, 1, 1), end: Date.new(year, 12, 31) }
      when /\A(\d{4})-(\d{1,2})\z/ # Year-month
        year = ::Regexp.last_match(1).to_i
        month = ::Regexp.last_match(2).to_i
        start_date = Date.new(year, month, 1)
        { start: start_date, end: start_date.end_of_month }
      else # Full date
        date = Date.parse(value.to_s)
        { start: date, end: date }
      end
    end
  end
end
