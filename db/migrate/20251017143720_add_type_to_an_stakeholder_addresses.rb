class AddTypeToAnStakeholderAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :an_stakeholder_addresses, :type, :integer, default: nil
  end
end
