class AddDateIndexesOnAnTerms < ActiveRecord::Migration[8.1]
  def change
    add_index :an_terms, [:start_date, :end_date], name: "index_terms_on_dates"

    add_index :an_terms,
              [:an_stakeholder_id, :end_date, :start_date],
              name: "index_an_terms_by_stakeholder_active",
              where: "start_date IS NOT NULL AND end_date IS NULL"

    add_index :an_terms,
              [:an_stakeholder_id, :start_date, :end_date],
              name: 'index_an_terms_by_stakeholder_past',
              where: 'start_date IS NOT NULL AND end_date IS NOT NULL'
  end
end
