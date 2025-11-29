class An::Correction < ApplicationRecord
  belongs_to :correctable, polymorphic: true

  before_validation :normalize_changes_keys, if: -> { correction_changes.present? }
  after_create :apply_to_correctable

  validates :correction_changes, :reason, :correction_type, :correctable, presence: true
  validate :fields_exist_on_correctable
  validate :correction_changes_structure

  scope :recent, -> { order(created_at: :desc) }

  private

  def normalize_changes_keys
    self.correction_changes = correction_changes.try(:deep_stringify_keys)
  end

  def fields_exist_on_correctable
    return if correction_changes.blank? || correctable.nil?

    correction_changes.each_key do |field|
      unless correctable.class.column_names.include?(field.to_s)
        errors.add(:correction_changes, "field '#{field}' does not exist on #{correctable.class.name}")
      end
    end
  end

  def correction_changes_structure
    return if correction_changes.blank?

    correction_changes.each do |field, data|
      unless data.is_a?(Hash)
        errors.add(:correction_changes, "field '#{field}' must be a hash")
        next
      end

      unless data.key?("before")
        errors.add(:correction_changes, "field '#{field}' must have a 'before' key")
      end

      unless data.key?("after")
        errors.add(:correction_changes, "field '#{field}' must have an 'after' key")
      end
    end
  end

  def apply_to_correctable
    return unless correctable

    attributes = correction_changes.each_with_object({}) do |(field, data), hash|
      hash[field.to_sym] = data["after"]
    end

    # callbacks will be called
    # pay attention not to chain a loads of queries
    correctable.update(attributes)
  end
end
