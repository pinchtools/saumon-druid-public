class An::BodyType < ApplicationRecord
  has_many :an_bodies, class_name: "An::Body", foreign_key: :an_body_type_id, inverse_of: :an_body_type, dependent: :destroy

  validates :code, presence: true, uniqueness: true
end
