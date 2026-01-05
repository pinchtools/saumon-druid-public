class AddPoliticalCampToAnBodies < ActiveRecord::Migration[8.1]
  def change
    add_column :an_bodies, :political_camp, :string
  end
end
