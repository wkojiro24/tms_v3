class AddCellStateToVehicleFinancialMetrics < ActiveRecord::Migration[7.2]
  def change
    add_column :vehicle_financial_metrics, :cell_state, :string, default: "value", null: false

    # 既存データを更新: value_numeric も value_text も無い場合は blank とみなす
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE vehicle_financial_metrics
          SET cell_state = 'blank'
          WHERE value_numeric IS NULL AND (value_text IS NULL OR value_text = '')
        SQL
      end
    end
  end
end
