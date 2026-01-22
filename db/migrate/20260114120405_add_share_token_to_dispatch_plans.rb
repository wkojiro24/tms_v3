class AddShareTokenToDispatchPlans < ActiveRecord::Migration[7.2]
  def change
    add_column :dispatch_plans, :share_token, :string
    add_column :dispatch_plans, :share_token_expires_at, :datetime
  end
end
