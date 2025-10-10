class An::Country < ApplicationRecord
  validates :uid, presence: true, uniqueness: true
  validates :name, presence: true
  validates :insee_code, presence: true, uniqueness: true
  validates :iso_code, presence: true, uniqueness: true
end
