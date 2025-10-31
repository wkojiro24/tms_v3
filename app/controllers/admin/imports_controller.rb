module Admin
  class ImportsController < BaseController
    before_action :authorize_import

    def new
      @periods = Period.ordered.limit(12)
    end

    def create
      files = Array.wrap(import_params[:files]).compact_blank
      expected_period = parse_period(import_params[:target_month])

      if files.empty?
        redirect_to new_admin_import_path, alert: "ファイルが選択されていません。" and return
      end

      unless expected_period
        redirect_to new_admin_import_path, alert: "対象月は YYYY-MM 形式で入力してください。" and return
      end

      results = files.map do |file|
        importer = Imports::PayrollImporter.new(
          file,
          uploaded_by: current_user,
          location: import_params[:location],
          expected_period: expected_period,
          period_mode: :strict
        )
        importer.call
      end

      hard_error = results.any?(&:hard_error?)
      messages = summarize_results(results)

      redirect_to new_admin_import_path, hard_error ? { alert: messages } : { notice: messages }
    end

    private

    def authorize_import
      authorize! :manage, :admin
    end

    def import_params
      params.require(:import).permit(:target_month, :location, files: [])
    end

    def parse_period(value)
      return if value.blank?
      return unless value.match?(/\A\d{4}-\d{2}\z/)

      year, month = value.split("-").map(&:to_i)
      Date.new(year, month, 1)
    rescue ArgumentError
      nil
    end

    def summarize_results(results)
      created = results.sum(&:created)
      updated = results.sum(&:updated)
      skipped = results.sum(&:skipped)

      messages = ["取り込み完了：作成 #{created} / 更新 #{updated} / スキップ #{skipped}"]

      results.flat_map(&:warnings).each do |warn|
        messages << "警告: #{warn[:message]}"
      end
      results.flat_map(&:errors).reject { |e| e[:hard] }.each do |error|
        messages << "エラー: #{error[:message]}"
      end

      messages.join("\n")
    end
  end
end
