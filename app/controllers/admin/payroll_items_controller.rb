# frozen_string_literal: true

module Admin
  class PayrollItemsController < BaseController
    def index
      @payroll_groups = Item::PAYROLL_GROUPS
      # グループ別に整理
      @grouped_items = {}
      Item::PAYROLL_GROUPS.keys.each do |group|
        @grouped_items[group] = Item.where(payroll_group: group)
                                    .order(:payroll_group_position, :name)
      end
      # 未設定
      @grouped_items[nil] = Item.where(payroll_group: nil)
                                .order(:name)
    end

    # Ajax: 単一項目のグループ変更
    def update
      item = Item.find(params[:id])
      if item.update(payroll_group: params[:payroll_group].presence)
        render json: { success: true, item_id: item.id, group: item.payroll_group }
      else
        render json: { success: false, errors: item.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Ajax: グループ内の並び順を一括更新
    def reorder
      params[:items]&.each_with_index do |item_id, index|
        Item.where(id: item_id).update_all(
          payroll_group: params[:group].presence,
          payroll_group_position: index
        )
      end
      render json: { success: true }
    end

    def update_groups
      params[:items]&.each do |item_id, item_params|
        item = Item.find_by(id: item_id)
        next unless item

        item.update(
          payroll_group: item_params[:payroll_group].presence,
          payroll_group_position: item_params[:position].to_i
        )
      end

      redirect_to admin_payroll_items_path, notice: "給与項目グループを更新しました。"
    end
  end
end
