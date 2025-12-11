class AddForeignKeysToAnBodiesCountries < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :an_bodies_countries, :an_bodies,
                    column: :an_body_id,
                    on_delete: :cascade

    add_foreign_key :an_bodies_countries, :an_countries,
                    column: :an_country_id,
                    on_delete: :cascade
  end
end
