class An::TermCorrectionDetector < An::BaseCorrectionDetector
  CORRECTIONS_CONFIG = YAML.load_file(
    Rails.root.join("config/corrections/term_corrections.yml")
  )["term_corrections"].freeze

  def detect
    CORRECTIONS_CONFIG.filter_map do |correction_config|
      apply_correction(correction_config) if matches_conditions?(correction_config["conditions"])
    end
  end
end
