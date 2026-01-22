class AddUnionFeeToSalaryMonthlies < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_monthlies, :union_fee, :integer
  end
end
