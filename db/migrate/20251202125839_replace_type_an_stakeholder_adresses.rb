class ReplaceTypeAnStakeholderAdresses < ActiveRecord::Migration[8.1]
  def change
    remove_column :an_stakeholder_addresses, :type, :integer
    add_column :an_stakeholder_addresses, :address_type, :string
  end
end
