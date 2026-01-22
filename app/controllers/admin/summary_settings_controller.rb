class Admin::SummarySettingsController < Admin::BaseController

  def edit
    @setting = SummarySetting.for(current_tenant)
  end

  def show
    redirect_to edit_admin_summary_setting_path
  end

  def update
    @setting = SummarySetting.for(current_tenant)
    permitted = params.require(:summary_setting).permit(:term_start_month, :fiscal_year_origin, label_mappings_keys: [], label_mappings_values: [])
    mappings = {};
    Array(permitted[:label_mappings_keys]).each_with_index do |label, idx|
      aliases = Array(permitted[:label_mappings_values])[idx].to_s.split(',').map(&:strip).reject(&:blank?)
      mappings[label] = (aliases.presence || [label])
    end
    @setting.term_start_month = permitted[:term_start_month]
    @setting.fiscal_year_origin = permitted[:fiscal_year_origin]
    @setting.label_mappings = mappings
    if @setting.save
      redirect_to edit_admin_summary_setting_path, notice: "サマリー設定を保存しました。"
    else
      flash.now[:alert] = "保存に失敗しました。"
      render :edit
    end
  end

  private

  def current_tenant
    ActsAsTenant.current_tenant
  end

end
