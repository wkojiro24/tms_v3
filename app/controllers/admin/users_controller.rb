module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:edit, :update]
    before_action :set_available_employments, only: [:edit, :update]

    def index
      @users = current_tenant.users.includes(:employment).order(:email)
    end

    def new
      @user = current_tenant.users.new(role: :staff)
      set_available_employments
    end

    def create
      permitted = user_params
      employment_attrs = permitted.delete(:new_employment)

      @user = current_tenant.users.new(permitted)
      assign_employment(@user, employment_attrs)

      set_available_employments_for_create
      if @user.save
        @user.employment.update!(submit_enabled: true) if @user.employment.present?
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
      employment_attrs = attrs.delete(:new_employment)

      if attrs[:password].blank?
        attrs = attrs.except(:password, :password_confirmation)
      end

      assign_employment(@user, employment_attrs) if employment_attributes_present?(employment_attrs)

      if @user.update(attrs)
        @user.employment.update!(submit_enabled: true) if @user.employment.present?
        redirect_to admin_users_path, notice: "ユーザー情報を更新しました。"
      else
        flash.now[:alert] = "ユーザー情報を更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = current_tenant.users.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :role, :employment_id, :password, :password_confirmation,
                                   new_employment: [:employee_code, :last_name, :first_name, :email])
    end

    def set_available_employments
      scope = current_tenant.employees.order(:employee_code)
      scope = scope.left_outer_joins(:user)

      if defined?(@user) && @user&.employment_id.present?
        scope = scope.where("users.id IS NULL OR employees.id = ?", @user.employment_id)
      else
        scope = scope.where(users: { id: nil })
      end

      @available_employments = scope
    end

    def set_available_employments_for_create
      scope = current_tenant.employees.order(:employee_code).left_outer_joins(:user)
      if @user&.employment_id.present?
        scope = scope.where("users.id IS NULL OR employees.id = ?", @user.employment_id)
      else
        scope = scope.where(users: { id: nil })
      end
      @available_employments = scope
    end

    def assign_employment(user, employment_attrs)
      return if user.employment_id.present?
      unless employment_attributes_present?(employment_attrs)
        user.errors.add(:employment, "を選択するか新規登録してください。")
        return
      end

      attrs = employment_attrs.to_h.symbolize_keys
      attrs.transform_values! { |value| value.is_a?(String) ? value.strip : value }
      attrs.compact_blank!
      attrs[:submit_enabled] = true
      attrs[:current_status] = "active"
      attrs[:hire_date] ||= Date.current

      employment = current_tenant.employees.build(attrs)
      user.employment = employment
    end

    def employment_attributes_present?(employment_attrs)
      employment_attrs.present? && employment_attrs.to_h.values.any?(&:present?)
    end
  end
end
