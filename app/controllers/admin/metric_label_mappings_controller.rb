module Admin
  class MetricLabelMappingsController < BaseController
    def index
      @unmapped_labels = unmapped_labels
      @category_items = MetricCategoryItem.includes(:metric_category)
                                          .references(:metric_category)
                                          .order("metric_categories.position ASC, metric_category_items.position ASC")
    end

    def create
      @item = MetricCategoryItem.find(params[:metric_category_item_id])
      label = params[:label].to_s.strip

      if label.blank?
        redirect_to admin_metric_label_mappings_path, alert: "ラベルを指定してください。" and return
      end

      labels = @item.source_label_list
      if labels.include?(label)
        redirect_to admin_metric_label_mappings_path, alert: "すでに追加済みのラベルです。" and return
      end

      @item.source_labels = labels + [label]
      if @item.save
        redirect_to admin_metric_label_mappings_path, notice: "マッピングを追加しました。"
      else
        redirect_to admin_metric_label_mappings_path, alert: "マッピングの追加に失敗しました。"
      end
    end

    private

    def unmapped_labels
      mapped = MetricCategoryItem.all.flat_map(&:source_label_list).map(&:to_s).reject(&:blank?).uniq
      all_labels = VehicleFinancialMetric.distinct.order(:metric_label).pluck(:metric_label).map(&:to_s)
      all_labels - mapped
    end
  end
end
