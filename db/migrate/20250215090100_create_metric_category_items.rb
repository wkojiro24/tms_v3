class CreateMetricCategoryItems < ActiveRecord::Migration[7.2]
  def change
    create_table :metric_category_items do |t|
      t.references :metric_category, null: false, foreign_key: true
      t.string :display_label, null: false
      t.text :source_labels, null: false, default: ""
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :metric_category_items, [:metric_category_id, :position], name: "index_metric_category_items_on_category_and_position"
  end
end
