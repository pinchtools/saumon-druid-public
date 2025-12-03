class An::TermCorrectionDetector < An::BaseCorrectionDetector
  CORRECTIONS_CONFIG = YAML.load_file(
    Rails.root.join("config/corrections/term_corrections.yml")
  )["term_corrections"].freeze
end
