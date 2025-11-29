class An::Body < ApplicationRecord
  belongs_to :an_body_type, class_name: "An::BodyType", inverse_of: :an_bodies
  belongs_to :parent, class_name: "An::Body", optional: true
  has_many :children, class_name: "An::Body", foreign_key: :parent_id, dependent: :destroy
  has_many :an_terms, class_name: "An::Term", foreign_key: :an_body_id, inverse_of: :an_body, dependent: :destroy
  has_many :constituency_terms, class_name: "An::Term", foreign_key: :constituency_id, dependent: :destroy
  has_and_belongs_to_many :an_countries,
                          class_name: "An::Country",
                          foreign_key: :an_body_id,
                          association_foreign_key: :an_country_id,
                          join_table: "an_bodies_countries"
  has_many :corrections, as: :correctable, class_name: "An::Correction", dependent: :destroy

  validates :uid, presence: true, uniqueness: true
  validates :an_body_type_id, presence: true

  scope :active, -> { where.not(start_date: nil).and(where(end_date: nil)) }
end
