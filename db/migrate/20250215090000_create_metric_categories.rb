class CreateMetricCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :metric_categories do |t|
      t.string :name, null: false
      t.string :display_label
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :metric_categories, :position
  end
end
