class AddHiddenToItems < ActiveRecord::Migration[7.2]
  def change
    add_column :items, :hidden, :boolean, default: false, null: false
  end
end
