class An::CorrectionDetector
  delegate :detect, to: :@delegator

  def initialize(record, api_data, session_id:)
    @record = record
    @delegator = delegator_class_name.new(record, api_data, session_id: session_id)
  end

  private

  def record_class_name
    @record.class.name.demodulize
  end

  def delegator_class_name
    "An::#{record_class_name}CorrectionDetector".constantize
  rescue NameError => e
    raise ArgumentError, "No correction detector found for #{record_class_name}: #{e.message}"
  end
end
