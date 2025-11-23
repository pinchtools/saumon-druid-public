class AddCapacityToAnTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :an_terms, :capacity, :string
  end
end
