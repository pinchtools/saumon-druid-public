class An::CorrectionApplier
  attr_reader :record, :session_id, :corrections_data

  def initialize(record, session_id:)
    @record = record
    @session_id = session_id
    @corrections_data = []
  end

  def detect_all
    @corrections_data += detector.detect_all

    self
  end

  def detect_one(name)
    @corrections_data << detector.detect_one(name)

    self
  end

  def apply
    @corrections_data.map do |correction_data|
      save_correction(correction_data)
    end
  end

  private

  def detector
    @detector ||= An::CorrectionDetector.new(record, session_id: session_id)
  end

  def save_correction(correction_data)
    correction = An::Correction.create(correctable: record, **correction_data)

    return correction if correction.persisted?

    Rails.logger.warn({
      message: "Failed to create correction for #{record.class.name}##{record.id}: " \
               "#{correction.errors.full_messages.join(', ')}",
      component: SaumonNet::COMPONENT,
      session_id: session_id,
      record_id: record.id,
      correction_errors: correction.errors.full_messages
    })

    nil
  end
end
