class AddApprovalFieldsToSalarySimulations < ActiveRecord::Migration[7.2]
  def change
    # 承認日時
    add_column :salary_simulations, :approved_at, :datetime
    # 承認者
    add_column :salary_simulations, :approved_by_id, :bigint
    # 承認メモ
    add_column :salary_simulations, :approval_note, :text

    add_index :salary_simulations, :approved_by_id
  end
end
