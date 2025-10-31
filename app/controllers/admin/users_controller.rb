module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:edit, :update]

    def index
      @users = User.order(:email)
    end

    def new
      @user = User.new(role: :staff)
    end

    def create
      @user = User.new(user_params)
      if @user.save
        redirect_to admin_users_path, notice: "ユーザーを作成しました。"
      else
        flash.now[:alert] = "ユーザーを作成できませんでした。入力内容をご確認ください。"
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attrs = user_params
      if attrs[:password].blank?
        attrs = attrs.except(:password, :password_confirmation)
      end

      if @user.update(attrs)
        redirect_to admin_users_path, notice: "ユーザー情報を更新しました。"
      else
        flash.now[:alert] = "ユーザー情報を更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :role, :password, :password_confirmation)
    end
  end
end
