module Admin
  class EvaluationCyclesController < BaseController
    before_action :set_evaluation_cycle, only: [:edit, :update, :destroy]

    def index
      @evaluation_cycles = current_tenant.evaluation_cycles.order(start_on: :desc)
      @evaluation_cycle = current_tenant.evaluation_cycles.new
    end

    def create
      @evaluation_cycle = current_tenant.evaluation_cycles.new(evaluation_cycle_params)
      if @evaluation_cycle.save
        redirect_to admin_evaluation_cycles_path, notice: "評価サイクルを登録しました。"
      else
        @evaluation_cycles = current_tenant.evaluation_cycles.order(start_on: :desc)
        flash.now[:alert] = "評価サイクルを登録できませんでした。"
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @evaluation_cycle.update(evaluation_cycle_params)
        redirect_to admin_evaluation_cycles_path, notice: "評価サイクルを更新しました。"
      else
        flash.now[:alert] = "評価サイクルを更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @evaluation_cycle.destroy
      redirect_to admin_evaluation_cycles_path, notice: "評価サイクルを削除しました。"
    end

    private

    def set_evaluation_cycle
      @evaluation_cycle = current_tenant.evaluation_cycles.find(params[:id])
    end

    def evaluation_cycle_params
      params.require(:evaluation_cycle).permit(:code, :name, :description, :start_on, :end_on, :active)
    end
  end
end
