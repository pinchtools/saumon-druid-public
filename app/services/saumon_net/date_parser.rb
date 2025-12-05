module SaumonNet
  module DateParser
    include Loggable

    extend self

    def parse_date(date_string, session_id: nil)
      return nil if date_string.blank? || !date_string.is_a?(String)

      Date.parse(date_string)
    rescue ArgumentError => e
      log_parse_error(session_id, date_string, e) if logger
      nil
    end

    def parse_datetime(date_string, session_id: nil)
      return nil if date_string.blank? || !date_string.is_a?(String)

      DateTime.parse(date_string)
    rescue ArgumentError => e
      log_parse_error(session_id, date_string, e) if logger
      nil
    end

    private

    def log_parse_error(session_id, date_string, error)
      logger.warn({
        message: "Failed to parse date",
        component: SaumonNet::COMPONENT,
        session_id: session_id,
        date_string: date_string,
        error: error.message
      })
    end
  end
end
