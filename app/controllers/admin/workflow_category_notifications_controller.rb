module Admin
  class WorkflowCategoryNotificationsController < BaseController
    before_action :set_category

    def create
      notification = @workflow_category.notifications.build(notification_params)
      if notification.save
        redirect_to admin_workflow_category_path(@workflow_category), notice: "通知先を追加しました。"
      else
        redirect_to admin_workflow_category_path(@workflow_category), alert: "通知先を追加できませんでした。"
      end
    end

    def destroy
      notification = @workflow_category.notifications.find(params[:id])
      notification.destroy
      redirect_to admin_workflow_category_path(@workflow_category), notice: "通知先を削除しました。"
    end

    private

    def set_category
      @workflow_category = WorkflowCategory.find(params[:workflow_category_id])
    end

    def notification_params
      params.require(:workflow_category_notification).permit(:role, :description)
    end
  end
end
