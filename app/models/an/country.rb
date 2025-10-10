class An::Country < ApplicationRecord
  has_and_belongs_to_many :an_bodies,
                          class_name: "An::Body",
                          join_table: "an_bodies_countries",
                          foreign_key: :an_country_id,
                          association_foreign_key: :an_body_id

  validates :uid, presence: true, uniqueness: true
  validates :name, presence: true
end
