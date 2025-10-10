class CreateJoinTableBodyCountry < ActiveRecord::Migration[8.0]
  def change
    create_join_table :an_bodies, :an_countries do |t|
      t.index [ :an_body_id, :an_country_id ], unique: true
    end
  end
end
