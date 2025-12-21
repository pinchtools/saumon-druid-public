# frozen_string_literal: true

module JsonRepairable
  extend ActiveSupport::Concern

  class RepairError < StandardError; end

  def repair_json(raw)
    return {} if raw.blank?

    content = raw.to_s.strip

    # Fast path: try parsing as-is
    return safe_parse(content) if valid_json?(content)

    # Extract from markdown/surrounding text
    content = extract_json_block(content)
    return safe_parse(content) if valid_json?(content)

    # Apply safe repairs (low risk of corruption)
    content = apply_safe_repairs(content)
    return safe_parse(content) if valid_json?(content)

    # Apply aggressive repairs (higher risk, but necessary for broken JSON)
    content = apply_aggressive_repairs(content)
    return safe_parse(content) if valid_json?(content)

    raise RepairError, "Unable to repair JSON: #{truncate_for_error(raw)}"
  end

  private

  def valid_json?(str)
    return false if str.blank?

    JSON.parse(str)
    true
  rescue JSON::ParserError
    false
  end

  def safe_parse(str)
    JSON.parse(str)
  end

  def extract_json_block(str)
    # Remove markdown code block wrappers
    extracted = str.sub(/\A.*?```(?:json)?\s*/m, "").sub(/```\s*\z/m, "")

    # If we found and removed markdown, try that first
    return extracted.strip if extracted != str && extracted.present?

    # Find first { or [ and last } or ]
    first_brace = str.index("{")
    first_bracket = str.index("[")
    last_brace = str.rindex("}")
    last_bracket = str.rindex("]")

    # Determine start position (first { or [)
    start_idx = [ first_brace, first_bracket ].compact.min
    return str unless start_idx

    # Determine end position (last } or ])
    end_idx = [ last_brace, last_bracket ].compact.max
    return str unless end_idx && end_idx > start_idx

    str[start_idx..end_idx]
  end

  def apply_safe_repairs(str)
    result = str.dup

    # Python booleans and None (safe - these are reserved keywords)
    result.gsub!(/\bTrue\b/, "true")
    result.gsub!(/\bFalse\b/, "false")
    result.gsub!(/\bNone\b/, "null")

    # Python NaN and Infinity (replace with null)
    result.gsub!(/\bNaN\b/, "null")
    result.gsub!(/-Infinity\b/, "null")
    result.gsub!(/\bInfinity\b/, "null")

    # Remove trailing commas before closing braces/brackets (safe)
    result.gsub!(/,(\s*[}\]])/, '\1')

    # Remove JavaScript-style comments (not valid in JSON)
    result.gsub!(%r{//[^\n]*(?:\n|$)}, "")
    result.gsub!(%r{/\*.*?\*/}m, "")

    # Normalize whitespace
    result.gsub!(/\r\n/, "\n")

    result.strip
  end

  def apply_aggressive_repairs(str)
    result = str.dup

    # Quote unquoted keys (common with LLMs outputting JS-style objects)
    result = quote_unquoted_keys(result)
    return result if valid_json?(result)

    # Fix single quotes used instead of double quotes (careful with apostrophes)
    result = fix_single_quotes(result)
    return result if valid_json?(result)

    # Insert missing commas between elements
    result = insert_missing_commas(result)
    return result if valid_json?(result)

    # Balance unclosed braces/brackets (for truncated output)
    result = balance_braces(result)

    result
  end

  def quote_unquoted_keys(str)
    # Match unquoted keys only at object key positions (after { or ,)
    # This is safer than matching anywhere in the string
    str.gsub(/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/) do
      "#{::Regexp.last_match(1)}\"#{::Regexp.last_match(2)}\":"
    end
  end

  MAX_REPAIR_ITERATIONS = 50

  def fix_single_quotes(str)
    # Strategy: only replace single quotes that appear to be JSON string delimiters
    # We look for patterns like 'value' or 'key': that suggest JSON structure
    result = str.dup

    # Replace single-quoted keys: 'key': -> "key":
    result.gsub!(/'([^']+)'\s*:/, '"\1":')

    # Replace single-quoted string values: : 'value' -> : "value"
    # But only when following a colon (to avoid apostrophes in text)
    result.gsub!(/:\s*'([^']*)'(\s*[,}\]])/, ': "\1"\2')

    # Replace single-quoted array elements (apply multiple times for all elements)
    MAX_REPAIR_ITERATIONS.times do
      prev = result.dup
      # First element in array
      result.gsub!(/\[\s*'([^']*)'\s*([,\]])/, '["\1"\2')
      # Subsequent elements after comma
      result.gsub!(/,\s*'([^']*)'\s*([,\]])/, ', "\1"\2')
      break if result == prev
    end

    result
  end

  def insert_missing_commas(str)
    result = str.dup

    # Between closing brace/bracket and opening quote or brace
    result.gsub!(/([}\]])\s+(?=["{\[])/, '\1, ')

    # Between closing brace/bracket and a key
    result.gsub!(/([}\]])\s+(?=[a-zA-Z_])/, '\1, ')

    # Between values in arrays (number/string followed by number/string)
    result.gsub!(/(")\s+(?=")/, '\1, ')
    result.gsub!(/(\d)\s+(?=\d)/, '\1, ')
    result.gsub!(/(")\s+(?=\d)/, '\1, ')
    result.gsub!(/(\d)\s+(?=")/, '\1, ')

    # Between true/false/null and next element
    result.gsub!(/(true|false|null)\s+(?=["{\[\dtfn])/i, '\1, ')

    result
  end

  def balance_braces(str)
    open_braces = str.count("{") - str.count("}")
    open_brackets = str.count("[") - str.count("]")

    # Only append missing closers (we can't safely prepend openers)
    result = str.dup
    result << ("}" * [ open_braces, 0 ].max)
    result << ("]" * [ open_brackets, 0 ].max)

    result
  end

  def truncate_for_error(str)
    str.to_s.truncate(100)
  end
end
