class DispatchPlansController < ApplicationController
  before_action :set_date, except: [:shared]
  before_action :set_depot, except: [:shared]
  before_action :set_dispatch_plan, only: [:show, :update]

  def index
    @dispatch_plan = DispatchPlan.find_or_create_for_date(@date)

    # 営業所リスト（フィルター用）
    @depots = Vehicle.where.not(depot_name: [nil, ""]).distinct.pluck(:depot_name).sort

    # 営業所でフィルタリング（車両のみ）
    base_vehicles = Vehicle.order(:registration_number)

    if @depot.present?
      base_vehicles = base_vehicles.where(depot_name: @depot)
    end

    @vehicles = base_vehicles
    # ドライバーは営業所に関係なく全員表示
    @employees = Employee.order(:last_name, :first_name)

    # 配車データも営業所でフィルタリング
    vehicle_ids = @vehicles.pluck(:id)
    @assignments = @dispatch_plan.dispatch_assignments
                                  .includes(:vehicle, :employee, :shipper, :destination_location)
                                  .where(vehicle_id: [nil] + vehicle_ids)
                                  .ordered

    @shippers = Shipper.order(:code)
    @destinations = Destination.order(:code)

    # 当日の荷物（TransportOrder）
    @transport_orders = TransportOrder.for_date(@date)
                                       .includes(:shipper, :origin_location, :destination_location, :vehicle)
                                       .ordered
    @unassigned_orders = @transport_orders.unassigned

    # 車両のデフォルト荷物紐付け設定
    @vehicle_cargo_bindings = VehicleCargoBinding.includes(:vehicle, :shipper, :default_origin, :default_destination)
                                                  .where(vehicle_id: @vehicles.pluck(:id))
                                                  .index_by(&:vehicle_id)

    # 車両ごとの配車データを構築
    @vehicle_assignments = build_vehicle_assignments

    # 車両ごとの備考（DispatchPlanのnotesにJSONで保存）
    @vehicle_memos = parse_vehicle_memos(@dispatch_plan.notes)
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: dispatch_plan_json }
    end
  end

  def update
    respond_to do |format|
      if @dispatch_plan.update(dispatch_plan_params)
        format.html { redirect_to dispatch_plans_path(date: @date), notice: "配車計画を更新しました。" }
        format.json { render json: { success: true } }
      else
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @dispatch_plan.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def batch_update
    updates = params[:assignments] || []
    errors = []

    ActiveRecord::Base.transaction do
      @dispatch_plan = DispatchPlan.find_or_create_for_date(@date)

      updates.each do |assignment_data|
        # IDが存在し、空文字列でもないことを確認
        assignment_id = assignment_data[:id].presence
        if assignment_id.present?
          # 既存の割当を更新
          assignment = @dispatch_plan.dispatch_assignments.find_by(id: assignment_id)
          if assignment
            unless assignment.update(assignment_params(assignment_data))
              errors << { id: assignment_id, errors: assignment.errors.full_messages }
            end
          else
            # IDが指定されているが見つからない場合はエラー
            errors << { id: assignment_id, errors: ["指定されたIDの配車が見つかりません"] }
          end
        elsif assignment_data[:_destroy] != "1"
          # 新規割当を作成
          assignment = @dispatch_plan.dispatch_assignments.build(assignment_params(assignment_data))
          unless assignment.save
            errors << { row: assignment_data[:row], errors: assignment.errors.full_messages }
          end
        end
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    respond_to do |format|
      if errors.empty?
        format.json { render json: { success: true, message: "#{updates.size}件を更新しました。" } }
      else
        format.json { render json: { success: false, errors: errors }, status: :unprocessable_entity }
      end
    end
  end

  def create_assignment
    @dispatch_plan = DispatchPlan.find_or_create_for_date(@date)
    @assignment = @dispatch_plan.dispatch_assignments.build(assignment_params(params))

    respond_to do |format|
      if @assignment.save
        format.json { render json: @assignment, status: :created }
      else
        format.json { render json: { errors: @assignment.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy_assignment
    @assignment = DispatchAssignment.find(params[:assignment_id])
    @assignment.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def confirm
    @dispatch_plan = DispatchPlan.find_or_create_for_date(@date)

    respond_to do |format|
      if @dispatch_plan.confirmed!
        format.json { render json: { success: true, message: "配車計画を確定しました" } }
      else
        format.json { render json: { success: false, error: "確定に失敗しました" }, status: :unprocessable_entity }
      end
    end
  end

  def unlock
    @dispatch_plan = DispatchPlan.find_or_create_for_date(@date)
    reason = params[:reason]

    respond_to do |format|
      if reason.present?
        # 解除理由をnotesに記録
        unlock_note = "【ロック解除】#{Time.current.strftime('%Y/%m/%d %H:%M')} by #{current_user&.email || 'unknown'}: #{reason}"
        new_notes = [@dispatch_plan.notes, unlock_note].compact.join("\n")
        @dispatch_plan.update!(status: :draft, notes: new_notes)
        format.json { render json: { success: true, message: "ロックを解除しました" } }
      else
        format.json { render json: { success: false, error: "解除理由が必要です" }, status: :unprocessable_entity }
      end
    end
  end

  def save_vehicle_memo
    @dispatch_plan = DispatchPlan.find_or_create_for_date(@date)
    vehicle_id = params[:vehicle_id].to_i
    memo = params[:memo].to_s.strip

    # 既存の備考をパース
    memos = parse_vehicle_memos(@dispatch_plan.vehicle_memos)
    memos[vehicle_id] = memo.presence

    # 空の備考は削除
    memos.compact!

    @dispatch_plan.update!(vehicle_memos: memos.to_json)

    respond_to do |format|
      format.json { render json: { success: true } }
    end
  end

  def update_default_driver
    vehicle_id = params[:vehicle_id].to_i
    employee_id = params[:employee_id].presence&.to_i

    vehicle = Vehicle.find(vehicle_id)

    respond_to do |format|
      if vehicle.update(default_employee_id: employee_id)
        format.json {
          render json: {
            success: true,
            vehicle_id: vehicle.id,
            default_employee_id: vehicle.default_employee_id,
            default_employee_name: vehicle.default_employee&.then { |e| "#{e.last_name} #{e.first_name&.first}" }
          }
        }
      else
        format.json { render json: { success: false, errors: vehicle.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def generate_share_token
    @dispatch_plan = DispatchPlan.find_or_create_for_date(@date)

    # トークン生成（24時間有効）
    token = SecureRandom.urlsafe_base64(32)
    expires_at = 24.hours.from_now

    @dispatch_plan.update!(
      share_token: token,
      share_token_expires_at: expires_at
    )

    # 共有URL生成
    depot = params[:depot]
    share_url = dispatch_share_url(token: token, host: request.host_with_port, protocol: request.protocol)
    share_url += "?depot=#{CGI.escape(depot)}" if depot.present?

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          share_url: share_url,
          expires_at: expires_at.strftime("%Y/%m/%d %H:%M")
        }
      }
    end
  end

  def shared
    # トークンで配車計画を検索
    @dispatch_plan = DispatchPlan.find_by(share_token: params[:token])

    if @dispatch_plan.nil?
      render plain: "共有URLが無効です", status: :not_found
      return
    end

    if @dispatch_plan.share_token_expires_at.nil? || @dispatch_plan.share_token_expires_at < Time.current
      render plain: "共有URLの有効期限が切れています", status: :gone
      return
    end

    @date = @dispatch_plan.date
    @depot = params[:depot]

    # データ取得
    base_vehicles = Vehicle.order(:registration_number)
    base_vehicles = base_vehicles.where(depot_name: @depot) if @depot.present?
    @vehicles = base_vehicles

    vehicle_ids = @vehicles.pluck(:id)
    @assignments = @dispatch_plan.dispatch_assignments
                                  .includes(:vehicle, :employee, :shipper, :destination_location)
                                  .where(vehicle_id: [nil] + vehicle_ids)
                                  .ordered

    @destinations = Destination.order(:code)
    @employees = Employee.order(:last_name, :first_name)
    @vehicle_memos = parse_vehicle_memos(@dispatch_plan.vehicle_memos)

    render :shared, layout: "shared"
  end

  private

  def set_date
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
  end

  def set_depot
    # URLパラメータから営業所を取得
    if params.key?(:depot)
      if params[:depot].present?
        @depot = params[:depot]
        session[:dispatch_depot] = @depot
      else
        # 明示的に全営業所を選択した場合（空文字列）
        @depot = nil
        session.delete(:dispatch_depot)
      end
    else
      # パラメータがない場合のみセッションから
      @depot = session[:dispatch_depot]
    end
  end

  def set_dispatch_plan
    @dispatch_plan = DispatchPlan.find_or_create_for_date(@date)
  end

  def dispatch_plan_params
    params.require(:dispatch_plan).permit(:notes, :status)
  end

  def assignment_params(data)
    data.permit(
      :id, :vehicle_id, :employee_id, :shipper_id, :sequence,
      :origin_location_id, :destination_location_id,
      :scheduled_departure, :scheduled_arrival, :estimated_return,
      :product_name, :cargo_type, :instruction, :route_instruction,
      :remarks, :status, :delivery_slip_confirmed, :transport_order_id,
      :alert_flag
    )
  end

  def build_vehicle_assignments
    # 車両ごとに配車データをまとめる
    result = {}
    @vehicles.each do |vehicle|
      vehicle_assignments = @assignments.select { |a| a.vehicle_id == vehicle.id }
      result[vehicle.id] = {
        vehicle: vehicle,
        assignments: vehicle_assignments.sort_by(&:sequence)
      }
    end
    result
  end

  def parse_vehicle_memos(json_str)
    return {} if json_str.blank?
    JSON.parse(json_str).transform_keys(&:to_i)
  rescue JSON::ParserError
    {}
  end

  def dispatch_plan_json
    {
      id: @dispatch_plan.id,
      date: @dispatch_plan.date,
      status: @dispatch_plan.status,
      notes: @dispatch_plan.notes,
      assignments: @dispatch_plan.dispatch_assignments.map do |a|
        {
          id: a.id,
          vehicle_id: a.vehicle_id,
          employee_id: a.employee_id,
          sequence: a.sequence,
          destination_name: a.destination_name,
          scheduled_departure: a.formatted_departure,
          scheduled_arrival: a.formatted_arrival,
          instruction: a.instruction,
          status: a.status
        }
      end
    }
  end
end
