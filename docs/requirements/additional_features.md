# TMS v3 機能追加要件定義書

## 既存プロジェクト概要

- **リポジトリ**: https://github.com/wkojiro24/tms_v3
- **技術スタック**: Rails 7 + PostgreSQL + マルチテナント
- **既存機能**:
  - 車両マスタ管理（`vehicles`テーブル）
  - 車両別名管理（`vehicle_aliases`）
  - 車両財務メトリクス（`vehicle_financial_metrics`）
  - 仕訳データ管理（`journal_entries/lines`）
  - ワークフロー承認機能
  - 給与管理
  - 従業員管理

---

## 追加機能の全体像

### 目的
運送会社の収支管理において、以下を実現する：
1. **荷主別按分計算**：複数荷主で共用する車両の費用配分
2. **顧客提示資料作成**：「見せ方」を記録し整合性を保った資料生成
3. **収支改善シミュレーション**：給与是正・車両入れ替え等の影響試算
4. **交渉証跡管理**：顧客との交渉内容・合意事項の記録
5. **専用車要求の証拠化**：「専用車ではない」という顧客の矛盾を可視化

---

## Phase 1: 荷主管理と按分計算 (最優先)

### 1-1. 荷主（顧客）マスタ

```ruby
# Migration
class CreateCustomers < ActiveRecord::Migration[7.2]
  def change
    create_table :customers do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :customer_code, null: false
      t.string :customer_name, null: false
      t.string :short_name
      t.text :notes
      t.boolean :active, default: true, null: false
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :customers, [:tenant_id, :customer_code], unique: true
  end
end

# Model
class Customer < ApplicationRecord
  belongs_to :tenant
  has_many :vehicle_customer_allocations
  has_many :allocation_results
  has_many :presentation_templates
  has_many :negotiation_histories
  
  validates :customer_code, presence: true, uniqueness: { scope: :tenant_id }
  validates :customer_name, presence: true
end
```

### 1-2. 按分ルール設定

```ruby
# Migration
class CreateVehicleCustomerAllocations < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicle_customer_allocations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      
      # 按分方式: revenue_ratio / distance_ratio / per_km / fixed
      t.string :allocation_method, null: false
      
      # 固定比率の場合（例: 60.0%）
      t.decimal :fixed_ratio, precision: 5, scale: 2
      
      # キロ単価の場合
      t.decimal :price_per_km, precision: 8, scale: 2
      
      # 有効期間
      t.date :valid_from, null: false
      t.date :valid_to
      
      t.text :reason_memo
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :vehicle_customer_allocations, 
              [:tenant_id, :vehicle_id, :customer_id, :valid_from],
              name: 'idx_allocations_unique'
  end
end

# Model
class VehicleCustomerAllocation < ApplicationRecord
  belongs_to :tenant
  belongs_to :vehicle
  belongs_to :customer
  
  ALLOCATION_METHODS = %w[revenue_ratio distance_ratio per_km fixed].freeze
  
  validates :allocation_method, inclusion: { in: ALLOCATION_METHODS }
  validates :valid_from, presence: true
  
  # 按分率の合計が100%かチェック（fixed方式の場合）
  validate :total_ratio_is_100_percent, if: -> { allocation_method == 'fixed' }
  
  def total_ratio_is_100_percent
    return unless vehicle && valid_from
    
    allocations = VehicleCustomerAllocation
      .where(vehicle: vehicle, allocation_method: 'fixed')
      .where('valid_from <= ? AND (valid_to IS NULL OR valid_to >= ?)', 
             valid_from, valid_from)
      .where.not(id: id)
    
    total = allocations.sum(:fixed_ratio) + (fixed_ratio || 0)
    
    if total != 100.0
      errors.add(:fixed_ratio, "按分率の合計が100%になりません（現在: #{total}%）")
    end
  end
end
```

### 1-3. 按分計算サービス

```ruby
# app/services/allocation_calculator.rb
class AllocationCalculator
  def initialize(vehicle, year_month, tenant)
    @vehicle = vehicle
    @year_month = year_month
    @tenant = tenant
  end
  
  def calculate
    allocations = fetch_allocations
    total_cost = calculate_total_cost
    
    allocations.map do |allocation|
      ratio = calculate_ratio(allocation)
      
      AllocationResult.create!(
        tenant: @tenant,
        vehicle: @vehicle,
        customer: allocation.customer,
        year_month: @year_month,
        allocation_method: allocation.allocation_method,
        total_cost: total_cost,
        allocation_ratio: ratio,
        allocated_cost: total_cost * ratio / 100,
        allocated_revenue: calculate_allocated_revenue(allocation, ratio),
        allocated_profit: 0, # 後で計算
        calculation_detail: build_detail(allocation, ratio)
      )
    end
  end
  
  private
  
  def fetch_allocations
    VehicleCustomerAllocation
      .where(tenant: @tenant, vehicle: @vehicle)
      .where('valid_from <= ? AND (valid_to IS NULL OR valid_to >= ?)', 
             @year_month, @year_month)
  end
  
  def calculate_total_cost
    # vehicle_financial_metricsから費用項目を集計
    VehicleFinancialMetric
      .where(tenant: @tenant, vehicle: @vehicle, month: @year_month)
      .where("metric_key LIKE ?", "%cost%")
      .sum(:value_numeric) || 0
  end
  
  def calculate_ratio(allocation)
    case allocation.allocation_method
    when 'revenue_ratio'
      calculate_revenue_ratio(allocation)
    when 'distance_ratio'
      calculate_distance_ratio(allocation)
    when 'per_km'
      # キロ単価の場合は別ロジック
      0
    when 'fixed'
      allocation.fixed_ratio
    else
      0
    end
  end
  
  def calculate_revenue_ratio(allocation)
    # 車両の総売上を取得
    total_revenue = VehicleFinancialMetric
      .where(tenant: @tenant, vehicle: @vehicle, month: @year_month)
      .where(metric_key: 'revenue')
      .sum(:value_numeric) || 0
    
    return 0 if total_revenue.zero?
    
    # 荷主別売上データが必要（別途実装）
    # 仮実装: 固定比率を返す
    allocation.fixed_ratio || 0
  end
  
  def calculate_distance_ratio(allocation)
    # 走行距離データが必要（別途実装）
    allocation.fixed_ratio || 0
  end
  
  def calculate_allocated_revenue(allocation, ratio)
    total_revenue = VehicleFinancialMetric
      .where(tenant: @tenant, vehicle: @vehicle, month: @year_month)
      .where(metric_key: 'revenue')
      .sum(:value_numeric) || 0
    
    total_revenue * ratio / 100
  end
  
  def build_detail(allocation, ratio)
    {
      allocation_method: allocation.allocation_method,
      calculated_ratio: ratio,
      basis: allocation.reason_memo,
      calculated_at: Time.current
    }
  end
end
```

### 1-4. 按分結果テーブル

```ruby
# Migration
class CreateAllocationResults < ActiveRecord::Migration[7.2]
  def change
    create_table :allocation_results do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.date :year_month, null: false
      
      # 計算根拠
      t.string :allocation_method, null: false
      t.decimal :total_cost, precision: 15, scale: 2, null: false
      t.decimal :allocation_ratio, precision: 5, scale: 2, null: false
      
      # 按分結果
      t.decimal :allocated_cost, precision: 15, scale: 2
      t.decimal :allocated_revenue, precision: 15, scale: 2
      t.decimal :allocated_profit, precision: 15, scale: 2
      
      t.jsonb :calculation_detail, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :allocation_results, 
              [:tenant_id, :vehicle_id, :customer_id, :year_month],
              unique: true,
              name: 'idx_allocation_results_unique'
  end
end
```

---

## Phase 2: 提示資料作成機能

### 2-1. 提示資料テンプレート

```ruby
# Migration
class CreatePresentationTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :presentation_templates do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      
      t.string :template_name, null: false
      t.string :version, default: 'v1.0'
      t.references :parent_template, foreign_key: { to_table: :presentation_templates }
      
      # 按分設定
      t.string :apportionment_method
      t.text :reason_memo
      
      # 項目統合ルール (JSON)
      # [{ group_name: '車両維持費', items: ['燃料費','車検費','修繕費'] }]
      t.jsonb :item_grouping_rules, default: [], null: false
      
      # 数値調整
      t.string :rounding_method # '万円切り上げ' etc
      t.jsonb :excluded_items, default: [], null: false
      
      # 表示レベル (1: 超シンプル, 2: 固変分解, 3: 詳細)
      t.integer :presentation_level, default: 1
      
      t.string :created_by
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :presentation_templates, 
              [:tenant_id, :customer_id, :template_name],
              name: 'idx_templates_unique'
  end
end

# Model
class PresentationTemplate < ApplicationRecord
  belongs_to :tenant
  belongs_to :customer
  belongs_to :parent_template, class_name: 'PresentationTemplate', optional: true
  has_many :child_templates, class_name: 'PresentationTemplate', foreign_key: :parent_template_id
  has_many :presentation_histories
  
  PRESENTATION_LEVELS = { simple: 1, breakdown: 2, detailed: 3 }.freeze
  
  validates :template_name, presence: true
  validates :presentation_level, inclusion: { in: PRESENTATION_LEVELS.values }
end
```

### 2-2. 提示資料生成履歴

```ruby
# Migration
class CreatePresentationHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :presentation_histories do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :presentation_template, null: false, foreign_key: true
      
      t.datetime :generation_date, null: false
      t.date :target_period_from
      t.date :target_period_to
      
      t.string :output_format # 'PDF' / 'Excel' / 'Word'
      t.string :file_path
      
      t.string :generated_by
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :presentation_histories, [:tenant_id, :generation_date]
  end
end
```

---

## Phase 3: シミュレーション機能

### 3-1. シミュレーションシナリオ

```ruby
# Migration
class CreateSimulationScenarios < ActiveRecord::Migration[7.2]
  def change
    create_table :simulation_scenarios do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :presentation_template, foreign_key: true
      
      t.string :scenario_name, null: false
      t.date :target_period_from
      t.date :target_period_to
      
      t.string :created_by
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
  end
end

# Model
class SimulationScenario < ApplicationRecord
  belongs_to :tenant
  belongs_to :customer
  belongs_to :presentation_template, optional: true
  has_many :simulation_items
  has_many :cost_fixed_variables
end
```

### 3-2. シミュレーション項目

```ruby
# Migration
class CreateSimulationItems < ActiveRecord::Migration[7.2]
  def change
    create_table :simulation_items do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :simulation_scenario, null: false, foreign_key: true
      
      # item_type: '給与是正' / '費用正常化' / '車両入れ替え'
      t.string :item_type, null: false
      
      t.decimal :current_value, precision: 15, scale: 2
      t.decimal :adjusted_value, precision: 15, scale: 2
      
      t.text :reason_memo
      t.jsonb :calculation_detail, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :simulation_items, [:tenant_id, :simulation_scenario_id]
  end
end
```

### 3-3. 固変分解

```ruby
# Migration
class CreateCostFixedVariables < ActiveRecord::Migration[7.2]
  def change
    create_table :cost_fixed_variables do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :simulation_scenario, null: false, foreign_key: true
      
      t.string :cost_category, null: false # '人件費' / '修繕費' etc
      
      # 固定費部分
      t.decimal :fixed_current, precision: 15, scale: 2
      t.decimal :fixed_adjusted, precision: 15, scale: 2
      t.text :fixed_reason
      
      # 変動費部分
      t.decimal :variable_current, precision: 15, scale: 2
      t.decimal :variable_adjusted, precision: 15, scale: 2
      t.text :variable_condition # 発生条件
      t.decimal :occurrence_rate, precision: 5, scale: 2 # 発生率78.5%
      t.string :occurrence_basis # '過去実績' / 'シーズン別' / '固定'
      
      # ブレンド提示設定
      t.integer :presentation_level # 1/2/3
      t.decimal :blended_amount, precision: 15, scale: 2 # 丸め後の提示額
      t.string :rounding_rule
      
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :cost_fixed_variables, [:tenant_id, :simulation_scenario_id]
  end
end
```

### 3-4. 変動費発生履歴

```ruby
# Migration
class CreateVariableCostHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :variable_cost_histories do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :cost_fixed_variable, null: false, foreign_key: true
      
      t.date :year_month, null: false
      t.integer :actual_distance # 実走行距離
      t.integer :threshold_distance # 条件の閾値
      t.boolean :occurred # 発生したか
      t.decimal :occurrence_amount, precision: 15, scale: 2
      
      t.timestamps
    end
    
    add_index :variable_cost_histories, 
              [:tenant_id, :cost_fixed_variable_id, :year_month],
              name: 'idx_variable_cost_histories_unique',
              unique: true
  end
end
```

### 3-5. 車両正規化

```ruby
# Migration
class CreateVehicleNormalizations < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicle_normalizations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :simulation_scenario, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      
      # 現状
      t.string :current_status # '償却済' / '償却中'
      t.decimal :current_annual_cost, precision: 15, scale: 2
      
      # 正規化計算
      t.decimal :normalized_cost, precision: 15, scale: 2 # 新車換算コスト
      t.text :normalization_method # 計算根拠
      
      # 適正台数での配分
      t.decimal :proposed_vehicle_count, precision: 3, scale: 1 # 6.5台
      t.decimal :allocated_cost, precision: 15, scale: 2
      
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :vehicle_normalizations, [:tenant_id, :simulation_scenario_id, :vehicle_id]
  end
end
```

---

## Phase 4: 交渉証跡管理

### 4-1. 交渉履歴

```ruby
# Migration
class CreateNegotiationHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :negotiation_histories do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      
      t.date :negotiation_date, null: false
      t.string :meeting_type # '対面' / '電話' / 'メール'
      
      t.jsonb :customer_attendees, default: [], null: false # ['山田部長','鈴木課長']
      t.jsonb :our_attendees, default: [], null: false
      
      t.text :our_request # 当社の要求
      t.text :customer_response # 顧客の回答
      t.jsonb :important_statements, default: [], null: false # 重要発言
      
      # 証跡ファイル（Active Storageで添付）
      # has_one_attached :meeting_minutes
      # has_one_attached :email_attachment
      
      t.boolean :agreement_reached, default: false
      t.text :agreement_content
      
      t.string :created_by
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :negotiation_histories, [:tenant_id, :customer_id, :negotiation_date]
  end
end

# Model
class NegotiationHistory < ApplicationRecord
  belongs_to :tenant
  belongs_to :customer
  
  has_one_attached :meeting_minutes
  has_one_attached :email_attachment
  
  validates :negotiation_date, presence: true
  validates :meeting_type, inclusion: { in: %w[対面 電話 メール] }
end
```

### 4-2. 合意管理

```ruby
# Migration
class CreateAgreements < ActiveRecord::Migration[7.2]
  def change
    create_table :agreements do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :negotiation_history, foreign_key: true
      
      t.date :agreement_date, null: false
      t.date :effective_date
      
      # 合意内容
      t.integer :vehicle_count_dedicated # 専用車台数
      t.decimal :vehicle_count_spot, precision: 3, scale: 1 # スポット車
      t.decimal :minimum_guarantee, precision: 15, scale: 2 # 最低保証額
      
      # 条件
      t.text :spot_conditions # スポット稼働条件
      t.text :increase_conditions # 増車条件
      t.integer :notice_period # 変更の事前通知期間(日)
      
      # 証跡
      t.boolean :confirmation_email_sent, default: false
      t.boolean :customer_confirmation_received, default: false
      # has_one_attached :confirmation_document
      
      # 有効性
      t.date :valid_until
      t.string :status, default: '有効' # '有効' / '失効' / '改定中'
      
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :agreements, [:tenant_id, :customer_id, :agreement_date]
    add_index :agreements, [:tenant_id, :status]
  end
end

# Model
class Agreement < ApplicationRecord
  belongs_to :tenant
  belongs_to :customer
  belongs_to :negotiation_history, optional: true
  
  has_one_attached :confirmation_document
  
  STATUSES = %w[有効 失効 改定中].freeze
  
  validates :agreement_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  
  scope :active, -> { where(status: '有効').where('valid_until IS NULL OR valid_until >= ?', Date.today) }
end
```

---

## Phase 5: 専用車要求の証拠化

### 5-1. 専用車仕様要求記録

```ruby
# Migration
class CreateDedicatedVehicleRequirements < ActiveRecord::Migration[7.2]
  def change
    create_table :dedicated_vehicle_requirements do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :vehicle, foreign_key: true
      
      t.date :requirement_date, null: false
      # requirement_type: 'タンク仕様' / '洗浄禁止' / '保管場所指定' etc
      t.string :requirement_type, null: false
      
      t.text :requirement_detail
      t.text :reason # 顧客の言い分
      
      # 証跡
      t.string :evidence_type # 'メール' / '仕様書' / '口頭'
      # has_one_attached :evidence_file
      
      # コスト影響
      t.decimal :initial_cost, precision: 15, scale: 2 # 初期投資
      t.decimal :annual_cost, precision: 15, scale: 2 # 年間コスト
      t.decimal :opportunity_loss, precision: 15, scale: 2 # 機会損失
      
      # ステータス
      t.boolean :currently_complying, default: true # 現在遵守しているか
      t.string :basis # 'contract' / 'verbal' / 'none'
      
      t.jsonb :metadata, default: {}, null: false
      
      t.timestamps
    end
    
    add_index :dedicated_vehicle_requirements, 
              [:tenant_id, :customer_id, :requirement_date],
              name: 'idx_dedicated_requirements'
  end
end

# Model
class DedicatedVehicleRequirement < ApplicationRecord
  belongs_to :tenant
  belongs_to :customer
  belongs_to :vehicle, optional: true
  
  has_one_attached :evidence_file
  
  REQUIREMENT_TYPES = %w[タンク仕様 洗浄禁止 保管場所指定 ドライバー教育 緊急対応].freeze
  EVIDENCE_TYPES = %w[メール 仕様書 口頭 契約書].freeze
  BASIS_TYPES = %w[contract verbal none].freeze
  
  validates :requirement_date, presence: true
  validates :requirement_type, inclusion: { in: REQUIREMENT_TYPES }
  validates :evidence_type, inclusion: { in: EVIDENCE_TYPES }, allow_nil: true
  validates :basis, inclusion: { in: BASIS_TYPES }, allow_nil: true
end
```

### 5-2. 専用車度スコア計算

```ruby
# app/services/dedicated_vehicle_score_calculator.rb
class DedicatedVehicleScoreCalculator
  def initialize(vehicle, customer, year_month, tenant)
    @vehicle = vehicle
    @customer = customer
    @year_month = year_month
    @tenant = tenant
  end
  
  def calculate
    score = 0
    
    # 1. 稼働時間専有率 (30%)
    utilization_rate = calculate_utilization_rate
    score += utilization_rate * 0.3
    
    # 2. 混載率（低いほど専用） (30%)
    mixed_rate = calculate_mixed_loading_rate
    score += (100 - mixed_rate) * 0.3
    
    # 3. 車両待機場所 (20%)
    parking_rate = calculate_customer_parking_rate
    score += parking_rate * 0.2
    
    # 4. ドライバー専属度 (20%)
    driver_dedication = calculate_driver_dedication_rate
    score += driver_dedication * 0.2
    
    score
  end
  
  private
  
  def calculate_utilization_rate
    # vehicle_financial_metricsから稼働データを取得
    # 実装は別途
    85.0
  end
  
  def calculate_mixed_loading_rate
    # 混載率を計算
    # 実装は別途
    7.0
  end
  
  def calculate_customer_parking_rate
    # 顧客倉庫前での待機率
    # 実装は別途
    87.0
  end
  
  def calculate_driver_dedication_rate
    # ドライバーの専属度
    # 実装は別途
    80.0
  end
end
```

---

## API設計（追加分）

### RESTful API エンドポイント

```ruby
# config/routes.rb に追加

namespace :api do
  namespace :v1 do
    # 荷主管理
    resources :customers do
      member do
        get :allocations
        get :negotiations
        get :agreements
      end
    end
    
    # 按分管理
    resources :vehicle_customer_allocations
    post 'allocations/calculate', to: 'allocations#calculate'
    get 'allocation_results', to: 'allocations#results'
    
    # 提示資料
    resources :presentation_templates do
      member do
        post :duplicate # バージョン複製
        post :generate  # 資料生成
      end
    end
    
    resources :presentation_histories, only: [:index, :show]
    
    # シミュレーション
    resources :simulation_scenarios do
      member do
        post :calculate
        get :compare
      end
      resources :simulation_items
      resources :cost_fixed_variables
    end
    
    # 交渉管理
    resources :negotiation_histories do
      member do
        post :generate_confirmation_email
      end
    end
    
    resources :agreements do
      member do
        post :send_confirmation
        post :mark_confirmed
      end
    end
    
    # 専用車要求
    resources :dedicated_vehicle_requirements
    get 'dedicated_score/:vehicle_id/:customer_id', 
        to: 'dedicated_requirements#calculate_score'
  end
end
```

---

## コントローラー実装例

### 按分計算コントローラー

```ruby
# app/controllers/api/v1/allocations_controller.rb
module Api
  module V1
    class AllocationsController < BaseController
      def calculate
        vehicle = current_tenant.vehicles.find(params[:vehicle_id])
        year_month = Date.parse(params[:year_month])
        
        calculator = AllocationCalculator.new(vehicle, year_month, current_tenant)
        results = calculator.calculate
        
        render json: {
          vehicle_id: vehicle.id,
          year_month: year_month,
          allocations: results.map { |r| AllocationResultSerializer.new(r) }
        }
      end
      
      def results
        results = AllocationResult
          .where(tenant: current_tenant)
          .includes(:vehicle, :customer)
        
        results = results.where(vehicle_id: params[:vehicle_id]) if params[:vehicle_id]
        results = results.where(customer_id: params[:customer_id]) if params[:customer_id]
        results = results.where(year_month: params[:year_month]) if params[:year_month]
        
        render json: results, each_serializer: AllocationResultSerializer
      end
    end
  end
end
```

### シミュレーションコントローラー

```ruby
# app/controllers/api/v1/simulation_scenarios_controller.rb
module Api
  module V1
    class SimulationScenariosController < BaseController
      def calculate
        scenario = current_tenant.simulation_scenarios.find(params[:id])
        
        # 各シミュレーション項目を計算
        results = {
          current_total: 0,
          adjusted_total: 0,
          difference: 0,
          items: []
        }
        
        scenario.simulation_items.each do |item|
          results[:current_total] += item.current_value
          results[:adjusted_total] += item.adjusted_value
          results[:items] << {
            type: item.item_type,
            current: item.current_value,
            adjusted: item.adjusted_value,
            difference: item.adjusted_value - item.current_value
          }
        end
        
        results[:difference] = results[:adjusted_total] - results[:current_total]
        
        render json: results
      end
      
      def compare
        scenario = current_tenant.simulation_scenarios.find(params[:id])
        
        # 複数シナリオの比較
        # 実装は別途
        
        render json: { scenario: scenario }
      end
    end
  end
end
```

---

## フロントエンド実装ガイド

### React Component例（按分設定画面）

```typescript
// app/javascript/components/AllocationForm.tsx
import React, { useState } from 'react';

interface AllocationFormProps {
  vehicleId: number;
  customerId: number;
  onSave: (data: AllocationData) => void;
}

interface AllocationData {
  allocation_method: string;
  fixed_ratio?: number;
  price_per_km?: number;
  valid_from: string;
  valid_to?: string;
  reason_memo?: string;
}

export const AllocationForm: React.FC<AllocationFormProps> = ({
  vehicleId,
  customerId,
  onSave
}) => {
  const [method, setMethod] = useState<string>('fixed');
  const [fixedRatio, setFixedRatio] = useState<number>(0);
  const [pricePerKm, setPricePerKm] = useState<number>(0);
  const [reasonMemo, setReasonMemo] = useState<string>('');
  
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    const data: AllocationData = {
      allocation_method: method,
      valid_from: new Date().toISOString().split('T')[0],
      reason_memo: reasonMemo
    };
    
    if (method === 'fixed') {
      data.fixed_ratio = fixedRatio;
    } else if (method === 'per_km') {
      data.price_per_km = pricePerKm;
    }
    
    onSave(data);
  };
  
  return (
    <form onSubmit={handleSubmit} className="allocation-form">
      <h2>按分ルール設定</h2>
      
      <div className="form-group">
        <label>按分方式</label>
        <select value={method} onChange={(e) => setMethod(e.target.value)}>
          <option value="revenue_ratio">売上比率</option>
          <option value="distance_ratio">走行距離比率</option>
          <option value="per_km">キロ単価</option>
          <option value="fixed">固定比率</option>
        </select>
      </div>
      
      {method === 'fixed' && (
        <div className="form-group">
          <label>固定比率（%）</label>
          <input
            type="number"
            step="0.01"
            value={fixedRatio}
            onChange={(e) => setFixedRatio(parseFloat(e.target.value))}
          />
        </div>
      )}
      
      {method === 'per_km' && (
        <div className="form-group">
          <label>キロ単価（円/km）</label>
          <input
            type="number"
            step="0.01"
            value={pricePerKm}
            onChange={(e) => setPricePerKm(parseFloat(e.target.value))}
          />
        </div>
      )}
      
      <div className="form-group">
        <label>選択理由メモ</label>
        <textarea
          value={reasonMemo}
          onChange={(e) => setReasonMemo(e.target.value)}
          placeholder="この按分方式を選択した理由を記録..."
        />
      </div>
      
      <button type="submit">保存</button>
    </form>
  );
};
```

---

## テスト実装

### RSpec例

```ruby
# spec/services/allocation_calculator_spec.rb
require 'rails_helper'

RSpec.describe AllocationCalculator do
  let(:tenant) { create(:tenant) }
  let(:vehicle) { create(:vehicle, tenant: tenant) }
  let(:customer_a) { create(:customer, tenant: tenant, customer_code: 'A') }
  let(:customer_b) { create(:customer, tenant: tenant, customer_code: 'B') }
  let(:year_month) { Date.new(2024, 1, 1) }
  
  describe '#calculate' do
    context '固定比率按分' do
      before do
        create(:vehicle_customer_allocation,
               tenant: tenant,
               vehicle: vehicle,
               customer: customer_a,
               allocation_method: 'fixed',
               fixed_ratio: 60.0,
               valid_from: year_month - 1.month)
        
        create(:vehicle_customer_allocation,
               tenant: tenant,
               vehicle: vehicle,
               customer: customer_b,
               allocation_method: 'fixed',
               fixed_ratio: 40.0,
               valid_from: year_month - 1.month)
        
        # 車両の総費用: 1000万円
        create(:vehicle_financial_metric,
               tenant: tenant,
               vehicle: vehicle,
               month: year_month,
               metric_key: 'total_cost',
               value_numeric: 10_000_000)
      end
      
      it '按分率通りに費用を配分する' do
        calculator = described_class.new(vehicle, year_month, tenant)
        results = calculator.calculate
        
        expect(results.size).to eq(2)
        
        result_a = results.find { |r| r.customer == customer_a }
        result_b = results.find { |r| r.customer == customer_b }
        
        expect(result_a.allocation_ratio).to eq(60.0)
        expect(result_a.allocated_cost).to eq(6_000_000)
        
        expect(result_b.allocation_ratio).to eq(40.0)
        expect(result_b.allocated_cost).to eq(4_000_000)
      end
    end
  end
end

# spec/models/vehicle_customer_allocation_spec.rb
require 'rails_helper'

RSpec.describe VehicleCustomerAllocation do
  let(:tenant) { create(:tenant) }
  let(:vehicle) { create(:vehicle, tenant: tenant) }
  
  describe 'validations' do
    context '固定比率按分の場合' do
      it '按分率の合計が100%でない場合はエラー' do
        customer_a = create(:customer, tenant: tenant)
        customer_b = create(:customer, tenant: tenant)
        
        create(:vehicle_customer_allocation,
               tenant: tenant,
               vehicle: vehicle,
               customer: customer_a,
               allocation_method: 'fixed',
               fixed_ratio: 60.0,
               valid_from: Date.today)
        
        allocation_b = build(:vehicle_customer_allocation,
                            tenant: tenant,
                            vehicle: vehicle,
                            customer: customer_b,
                            allocation_method: 'fixed',
                            fixed_ratio: 50.0, # 合計110%になる
                            valid_from: Date.today)
        
        expect(allocation_b).not_to be_valid
        expect(allocation_b.errors[:fixed_ratio]).to include(/100%/)
      end
    end
  end
end
```

---

## マイグレーション実行順序

```bash
# Phase 1: 荷主管理と按分計算
rails g migration CreateCustomers
rails g migration CreateVehicleCustomerAllocations
rails g migration CreateAllocationResults

# Phase 2: 提示資料
rails g migration CreatePresentationTemplates
rails g migration CreatePresentationHistories

# Phase 3: シミュレーション
rails g migration CreateSimulationScenarios
rails g migration CreateSimulationItems
rails g migration CreateCostFixedVariables
rails g migration CreateVariableCostHistories
rails g migration CreateVehicleNormalizations

# Phase 4: 交渉管理
rails g migration CreateNegotiationHistories
rails g migration CreateAgreements

# Phase 5: 専用車要求
rails g migration CreateDedicatedVehicleRequirements

# 実行
rails db:migrate
```

---

## Seed データ例

```ruby
# db/seeds/additional_features.rb

# 既存のテナントを取得
tenant = Tenant.first

# サンプル荷主作成
customer_seishin = Customer.create!(
  tenant: tenant,
  customer_code: 'SEISHIN',
  customer_name: '信越化学工業株式会社',
  short_name: '信越',
  active: true
)

customer_mitsubishi = Customer.create!(
  tenant: tenant,
  customer_code: 'MITSUBISHI',
  customer_name: '三菱ケミカル株式会社',
  short_name: '三菱ケミカル',
  active: true
)

# サンプル車両を取得（既存データから）
vehicle = tenant.vehicles.first

# 按分ルール作成
VehicleCustomerAllocation.create!(
  tenant: tenant,
  vehicle: vehicle,
  customer: customer_seishin,
  allocation_method: 'fixed',
  fixed_ratio: 60.0,
  valid_from: Date.new(2024, 1, 1),
  reason_memo: 'メタノール専用車として主に使用'
)

VehicleCustomerAllocation.create!(
  tenant: tenant,
  vehicle: vehicle,
  customer: customer_mitsubishi,
  allocation_method: 'fixed',
  fixed_ratio: 40.0,
  valid_from: Date.new(2024, 1, 1),
  reason_memo: 'スポット利用'
)

puts "✅ Additional features seeded successfully!"
puts "   - Customers: #{Customer.count}"
puts "   - Allocations: #{VehicleCustomerAllocation.count}"
```

---

## 次のステップ

### Claude Codeへの依頼方法

1. **Phase 1から順次実装**
   ```
   既存のtms_v3プロジェクトに、以下の機能を追加してください：
   
   Phase 1: 荷主管理と按分計算
   - Customerモデル作成
   - VehicleCustomerAllocationモデル作成
   - AllocationCalculatorサービス作成
   - API実装
   
   マイグレーションファイルとモデルのコードは上記の要件定義書を参照してください。
   ```

2. **既存コードとの統合確認**
   - `vehicles` テーブルとの関連を確認
   - `vehicle_financial_metrics` からデータ取得ロジックを実装
   - マルチテナント対応（`tenant_id`）を徹底

3. **テストコード作成**
   - 各モデルのバリデーションテスト
   - サービスクラスの単体テスト
   - API統合テスト

4. **フロントエンド実装**
   - 既存のRails viewsに統合
   - または React componentsとして追加

---

## 補足: 既存機能の活用

### vehicle_financial_metricsの活用

既存の `vehicle_financial_metrics` テーブルは柔軟なkey-value形式なので、
按分計算に必要なデータ（売上、走行距離等）を追加できます：

```ruby
# 売上データを追加
VehicleFinancialMetric.create!(
  tenant: tenant,
  vehicle: vehicle,
  vehicle_code: vehicle.registration_number,
  month: Date.new(2024, 1, 1),
  metric_key: 'revenue',
  metric_label: '売上',
  value_numeric: 8_000_000,
  unit: '円'
)

# 走行距離データを追加
VehicleFinancialMetric.create!(
  tenant: tenant,
  vehicle: vehicle,
  vehicle_code: vehicle.registration_number,
  month: Date.new(2024, 1, 1),
  metric_key: 'distance',
  metric_label: '走行距離',
  value_numeric: 5_000,
  unit: 'km'
)
```

これにより、既存のインポート機能を活用しつつ、
新機能に必要なデータを蓄積できます。

---

以上が既存プロジェクトへの機能追加要件定義です。
Claude Codeに段階的に実装を依頼してください！