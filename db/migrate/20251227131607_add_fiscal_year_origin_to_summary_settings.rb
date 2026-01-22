class AddFiscalYearOriginToSummarySettings < ActiveRecord::Migration[7.2]
  def change
    add_column :summary_settings, :fiscal_year_origin, :integer
  end
end
