# 車両機能 要件定義書

## 概要

### 目的
- 車両マスタ情報の管理
- 車両別収支データの管理・分析
- 整備・点検計画の管理
- 故障・ステータス管理

### サブメニュー構成
- 車両一覧 (`/vehicles`)
- 収支グリッド (`/vehicle_financials`)
- 整備計画 (`/maintenance`)
- 車両別収支 (`/revenue`)

---

## 1. 車両マスタ（Vehicle）

### 基本項目

| 項目名 | カラム | 型 | 必須 | 説明 |
|--------|--------|-----|------|------|
| 営業所 | depot_name | string | - | 所属営業所 |
| 登録番号 | registration_number | string | ◯ | 車両ナンバー（正規形式） |
| 社番 | call_sign | string | - | 社内呼称番号 |
| 初度登録日 | first_registration_on | date | - | 初度登録年月日 |
| 車齢テキスト | age_text | string | - | 車齢表示用 |
| 型式 | model_code | string | - | 車両型式 |
| メーカー | manufacturer_name | string | - | 車両メーカー |
| 車台番号 | chassis_number | string | - | 車台番号 |
| 車両区分 | vehicle_category | string | - | 車両区分 |
| 最大積載量(kg) | max_load_kg | integer | - | 最大積載量 |
| 車両総重量(kg) | gross_weight_kg | integer | - | 車両総重量 |
| シャーシベース | chassis_base | string | - | シャーシベース |
| PTO | pto | string | - | PTO情報 |
| 荷主名 | shipper_name | string | - | 主要荷主 |
| 積載物 | cargo_name | string | - | 主要積載物 |
| 比重 | specific_gravity | string | - | 積載物比重 |
| タンク製造日 | tank_made_on | date | - | タンク製造年月日 |
| タンク齢テキスト | tank_age_text | string | - | タンク齢表示用 |
| ハッチパターン | hatch_pattern | string | - | ハッチパターン |
| タンク材質 | tank_material | string | - | タンク材質 |
| タンクメーカー | tank_manufacturer | string | - | タンク製造メーカー |
| タイヤ本数 | tire_count | integer | - | タイヤ本数 |
| ボディタイプ | body_type | string | - | ボディタイプ |
| 用途区分 | usage_category | string | - | 用途区分 |
| 備考 | notes | text | - | 備考 |
| メタデータ | metadata | jsonb | ◯ | 拡張項目用 |

### 一意制約
- `tenant_id` + `registration_number` + `first_registration_on` で一意

### 関連機能
- 写真添付: Active Storage使用、最大20枚まで

---

## 2. 故障ステータス（fault_status）

### enum定義

| 値 | 説明 |
|----|------|
| normal (0) | 正常 |
| faulted (1) | 故障中 |
| suspended (1) | 休車中（故障で使用停止） |
| reduced (2) | 能力低下 |

### VehicleFault（故障履歴）

| 項目名 | カラム | 型 | 必須 | 説明 |
|--------|--------|-----|------|------|
| vehicle_id | reference | ◯ | 対象車両 |
| started_on | date | ◯ | 故障開始日 |
| resolved_on | date | - | 解決日（nullなら未解決） |
| summary | string | ◯ | 故障概要 |

- 未解決の故障がある場合、車両の`fault_status`を自動で`faulted`に更新

---

## 3. 車両ステータス（VehicleStatus）

### ステータス種別

| 値 | ラベル | 説明 |
|----|--------|------|
| active | 稼働中 | 通常稼働 |
| maintenance | 整備中 | 整備作業中 |
| inspection | 点検予定 | 点検予定あり |
| attention | 注意 | 要注意状態 |
| out_of_service | 休車 | 使用停止 |

### 項目

| 項目名 | カラム | 型 | 必須 | 説明 |
|--------|--------|-----|------|------|
| vehicle_id | reference | ◯ | 対象車両 |
| status | string | ◯ | ステータス |
| effective_on | date | ◯ | 有効日 |
| source | polymorphic | - | ステータス変更元（点検記録等） |

- 履歴形式で管理（最新のレコードが現在のステータス）

---

## 4. 点検記録（VehicleInspectionRecord）

### ステータス

| 値 | 説明 |
|----|------|
| scheduled | 予定 |
| completed | 完了 |
| overdue | 期限超過 |

### 項目

| 項目名 | カラム | 型 | 必須 | 説明 |
|--------|--------|-----|------|------|
| vehicle_id | reference | ◯ | 対象車両 |
| inspection_type | string | ◯ | 点検種別 |
| status | string | ◯ | ステータス |
| scheduled_on | date | ◯ | 予定日 |
| completed_on | date | - | 完了日 |

### 点検種別例
- 車検
- 3ヶ月点検
- 12ヶ月点検
- タンク検査
- 消防検査

---

## 5. 車両財務メトリクス（VehicleFinancialMetric）

### 目的
Excelからインポートした車両別収支データを格納。

### 項目

| 項目名 | カラム | 型 | 必須 | 説明 |
|--------|--------|-----|------|------|
| vehicle_id | reference | - | 紐づく車両（任意） |
| vehicle_code | string | ◯ | 車両コード |
| metric_key | string | ◯ | メトリクスキー |
| metric_label | string | ◯ | メトリクスラベル |
| month | date | ◯ | 対象月 |
| value_numeric | decimal | - | 数値 |
| value_text | string | - | テキスト値 |
| unit | string | - | 単位 |
| cell_state | enum | ◯ | セル状態 |

### セル状態（cell_state）

| 値 | 説明 |
|----|------|
| value | 実際の値がある（0含む） |
| blank | 元データが空白 |
| error | #DIV/0! 等のエラー |

### メトリクス例

| キー | ラベル | カテゴリ |
|------|--------|----------|
| revenue | 売上 | 収益 |
| fuel_cost | 燃料費 | 変動費 |
| repair_cost | 修繕費 | 変動費 |
| depreciation | 減価償却費 | 固定費 |
| driver_salary | ドライバー人件費 | 固定費 |
| insurance | 保険料 | 固定費 |
| distance | 走行距離 | 実績 |

---

## 6. 車両エイリアス（VehicleAlias）

### 目的
車両番号の表記ゆれを正規化するためのマッピングテーブル。

### 項目

| 項目名 | カラム | 型 | 必須 | 説明 |
|--------|--------|-----|------|------|
| pattern | string | ◯ | 別名パターン（例: "100番"） |
| pattern_type | string | ◯ | 'exact' または 'regex' |
| vehicle_id | string | ◯ | 正規ナンバー（例: "100"） |
| active | boolean | ◯ | 有効/無効 |

詳細は [vehicle_normalization_requirements.md](vehicle_normalization_requirements.md) を参照。

---

## 7. 車両グループ（VehicleGroup）

### 目的
車両を論理的にグループ化し、収支分析やレポート作成に使用。

### グループタイプ

| 値 | ラベル | 説明 |
|----|--------|------|
| shipper | 荷主別 | 荷主ごとのグループ |
| depot | 営業所別 | 営業所ごとのグループ |
| vehicle_type | 車両種別 | 車両タイプごとのグループ |
| custom | カスタム | 任意のグループ |

### 項目

| 項目名 | カラム | 型 | 必須 | 説明 |
|--------|--------|-----|------|------|
| name | string | ◯ | グループ名 |
| group_type | string | ◯ | グループタイプ |
| position | integer | - | 表示順 |
| vehicle_codes | jsonb | - | 車両コードリスト |
| code_mappings | jsonb | - | コードマッピング（別名→正規） |

### 機能
- 荷主別・営業所別グループの自動生成
- 正規化コードへの変換
- グループ内コード検索

---

## 8. 画面構成

### 8-1. 車両一覧（/vehicles）

| 機能 | 説明 |
|------|------|
| 一覧表示 | 登録番号、社番、営業所、荷主、ステータス等 |
| フィルタ | 営業所、荷主、ステータス |
| 詳細表示 | 車両詳細情報、写真、故障履歴、点検履歴 |
| 新規登録 | 車両マスタ登録 |
| 編集 | 車両情報編集 |

### 8-2. 収支グリッド（/vehicle_financials）

| 機能 | 説明 |
|------|------|
| グリッド表示 | 車両×月のマトリクス形式で収支表示 |
| 期間選択 | 年度・期間の選択 |
| メトリクス切替 | 表示するメトリクスの選択 |
| Excelインポート | 原価計算Excelからのデータ取込 |
| Excel出力 | グリッドデータのExcel出力 |
| フルスクリーン | 全画面表示モード |

### 8-3. 整備計画（/maintenance）

| 機能 | 説明 |
|------|------|
| カレンダー表示 | 点検・整備予定のカレンダー表示 |
| 一覧表示 | 予定・完了・期限超過の一覧 |
| 点検登録 | 新規点検予定の登録 |
| 完了処理 | 点検完了の記録 |

### 8-4. 車両別収支（/revenue）

| 機能 | 説明 |
|------|------|
| 車両選択 | 分析対象車両の選択 |
| 収支推移 | 月次収支の推移グラフ |
| 費目別内訳 | 費用項目別の内訳表示 |
| 比較分析 | 車両間・期間間の比較 |

---

## 9. データモデル（ER図概要）

```
Vehicle
  ├── has_many :financial_metrics (VehicleFinancialMetric)
  ├── has_many :vehicle_faults (VehicleFault)
  ├── has_many :vehicle_fault_logs (VehicleFaultLog)
  ├── has_many :vehicle_inspection_records (VehicleInspectionRecord)
  ├── has_many :vehicle_statuses (VehicleStatus)
  ├── has_many :maintenance_events (MaintenanceEvent)
  └── has_many_attached :photos

VehicleAlias
  └── 車両番号の表記ゆれマッピング

VehicleGroup
  └── 車両のグループ化（荷主別、営業所別等）
```

---

## 10. 実装状況

### 実装済み
- 車両マスタ CRUD
- 収支グリッド表示
- Excelインポート（原価計算）
- 車両エイリアス（名寄せ基盤）
- 車両グループ
- 故障ステータス管理
- 車両ステータス管理
- 点検記録管理
- 写真添付

### 未実装・検討中
- 整備計画カレンダー
- 車両別収支分析画面の詳細化
- グループ別集計レポート
- 車両マスタCSVインポート

---

## 11. 関連ドキュメント

- [車両名寄せ機能要件](vehicle_normalization_requirements.md) - 表記ゆれ対策の詳細
- [追加機能要件](additional_features.md) - 荷主別按分計算等

---

## 備考

- マルチテナント対応（TenantScoped）
- 車両番号は正規化して保存（名寄せエンジン使用）
- 写真は最大20枚まで
