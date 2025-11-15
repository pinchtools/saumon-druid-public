class Agent < ApplicationRecord
  before_validation :normalize_name

  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: true

  private

  def normalize_name
    self.normalized_name = name.downcase.gsub(/[^a-z0-9_]/, "_") if name
  end
end
