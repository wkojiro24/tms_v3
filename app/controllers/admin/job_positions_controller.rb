module Admin
  class JobPositionsController < BaseController
    before_action :set_job_position, only: [:edit, :update, :destroy]

    def index
      @job_positions = current_tenant.job_positions.order(:grade, :name)
      @job_position = current_tenant.job_positions.new
    end

    def create
      @job_position = current_tenant.job_positions.new(job_position_params)
      if @job_position.save
        redirect_to admin_job_positions_path, notice: "役職を登録しました。"
      else
        @job_positions = current_tenant.job_positions.order(:grade, :name)
        flash.now[:alert] = "役職を登録できませんでした。"
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @job_position.update(job_position_params)
        redirect_to admin_job_positions_path, notice: "役職情報を更新しました。"
      else
        flash.now[:alert] = "役職情報を更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @job_position.destroy
      redirect_to admin_job_positions_path, notice: "役職を削除しました。"
    end

    private

    def set_job_position
      @job_position = current_tenant.job_positions.find(params[:id])
    end

    def job_position_params
      params.require(:job_position).permit(:code, :name, :description, :grade, :active)
    end
  end
end
