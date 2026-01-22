class AddCalcUnionFeeToSalarySimulations < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_simulations, :calc_union_fee, :integer
  end
end
