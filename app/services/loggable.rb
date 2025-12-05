module Loggable
  def logger
    @logger ||= Rails.logger
  end
end
