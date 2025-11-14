class LlmModel < ApplicationRecord
  validates :external_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :family, presence: true
  validates :provider, presence: true
end
