class An::CorrectionDetector
  delegate :detect_all, :detect_one, to: :@delegator

  def initialize(record, session_id:)
    @record = record
    @delegator = delegator_class_name.new(record, session_id: session_id)
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
