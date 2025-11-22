module Admin
  class MetricCategoryItemsController < BaseController
    before_action :set_category
    before_action :set_item, only: [:edit, :update, :destroy]

    def new
    @item = @category.items.new
  end

  def create
    @item = @category.items.new(item_params)
    if @item.save
      redirect_to edit_admin_metric_category_path(@category), notice: "項目を追加しました。"
    else
      flash.now[:alert] = "項目を追加できませんでした。"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @item.update(item_params)
      respond_to do |format|
        format.html { redirect_to edit_admin_metric_category_path(@category), notice: "項目を更新しました。" }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = "項目を更新できませんでした。"
          render :edit, status: :unprocessable_entity
        end
        format.json { render json: { success: false, errors: @item.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

    def destroy
      @item.destroy
      redirect_to edit_admin_metric_category_path(@category), notice: "項目を削除しました。"
    end

    private

    def set_category
      @category = MetricCategory.find(params[:metric_category_id])
    end

    def set_item
      @item = @category.items.find(params[:id])
    end

    def item_params
      params.require(:metric_category_item).permit(:display_label, :source_label_text, :position)
    end
  end
end
