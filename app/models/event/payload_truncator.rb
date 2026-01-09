# frozen_string_literal: true

# Truncates event payloads for external reporting (e.g., Sentry)
# to avoid sending large amounts of data or sensitive information
class Event::PayloadTruncator
  MAX_STRING_LENGTH = 1000
  MAX_ARRAY_ITEMS = 10
  MAX_HASH_DEPTH = 3
  MAX_TOTAL_SIZE = 10_240 # 10KB

  def initialize(payload)
    @payload = payload.is_a?(Hash) ? payload.deep_dup : {}
    @parameter_filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
  end

  def truncate
    filtered = @parameter_filter.filter(@payload)

    truncated = truncate_value(filtered, depth: 0)

    if json_size(truncated) > MAX_TOTAL_SIZE
      truncated = aggressive_truncate(truncated)
    end

    truncated
  end

  private

  def truncate_value(value, depth:)
    return "[max depth exceeded]" if depth >= MAX_HASH_DEPTH

    case value
    when Hash
      truncate_hash(value, depth: depth)
    when Array
      truncate_array(value, depth: depth)
    when String
      truncate_string(value)
    else
      value
    end
  end

  def truncate_hash(hash, depth:)
    hash.each_with_object({}) do |(key, val), result|
      result[key] = truncate_value(val, depth: depth + 1)
    end
  end

  def truncate_array(array, depth:)
    truncated = array.first(MAX_ARRAY_ITEMS).map do |item|
      truncate_value(item, depth: depth + 1)
    end

    if array.size > MAX_ARRAY_ITEMS
      truncated << "[... #{array.size - MAX_ARRAY_ITEMS} more items]"
    end

    truncated
  end

  def truncate_string(string)
    return string if string.length <= MAX_STRING_LENGTH

    "#{string[0...MAX_STRING_LENGTH]}... [truncated #{string.length - MAX_STRING_LENGTH} chars]"
  end

  def aggressive_truncate(payload)
    aggressive_hash = {}

    payload.each do |key, value|
      case value
      when String
        aggressive_hash[key] = value.length > 200 ? "#{value[0...200]}..." : value
      when Array
        aggressive_hash[key] = [ "[#{value.size} items - truncated]" ]
      when Hash
        aggressive_hash[key] = { summary: "[nested hash - truncated]", keys: value.keys.first(5) }
      else
        aggressive_hash[key] = value
      end

      break if json_size(aggressive_hash) > MAX_TOTAL_SIZE
    end

    aggressive_hash
  end

  def json_size(value)
    value.to_json.bytesize
  end
end
