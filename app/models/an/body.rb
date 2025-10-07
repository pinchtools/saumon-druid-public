class An::Body < ApplicationRecord
  belongs_to :an_body_type, class_name: "An::BodyType", inverse_of: :an_bodies
  belongs_to :parent, class_name: "An::Body", optional: true
  has_many :children, class_name: "An::Body", foreign_key: :parent_id, dependent: :destroy
  has_many :an_terms, class_name: "An::Term", foreign_key: :an_body_id, inverse_of: :an_body, dependent: :destroy
  has_many :constituency_terms, class_name: "An::Term", foreign_key: :constituency_id, dependent: :destroy

  validates :uid, presence: true, uniqueness: true
  validates :an_body_type_id, presence: true
end
