# ワークフロー機能 要件定義書

## 概要

### 目的
- 社内の各種申請・承認プロセスを電子化
- 多段階承認フローの柔軟な設定
- 申請履歴の記録・検索

### 設計方針
- カテゴリごとに承認ステージを柔軟に設定可能
- ロールベースまたは個人指定での承認者設定
- 差し戻し・却下・保留に対応

---

## 機能要件

### 1. 申請カテゴリ管理（管理者機能）

#### WorkflowCategory
申請の種類を定義するマスタ。

| 項目名 | 型 | 必須 | 説明 |
|--------|-----|------|------|
| code | string | ◯ | カテゴリコード（一意） |
| name | string | ◯ | カテゴリ名 |
| description | text | - | 説明 |
| active | boolean | ◯ | 有効フラグ（デフォルト: true） |

#### 想定カテゴリ例
- `travel` - 出張申請
- `purchase` - 購買申請
- `repair` - 修繕申請
- `challenge` - チャレンジ申請
- `asset` - 資産・備品申請
- `incident` - 事故報告

### 2. 承認ステージテンプレート（管理者機能）

#### WorkflowStageTemplate
カテゴリごとのデフォルト承認ステージを定義。

| 項目名 | 型 | 必須 | 説明 |
|--------|-----|------|------|
| workflow_category_id | reference | ◯ | 所属カテゴリ |
| position | integer | ◯ | 承認順序（1から） |
| name | string | ◯ | ステージ名（例: 「上長承認」「経理承認」） |
| responsible_role | string | - | 承認担当ロール |
| responsible_user_id | reference | - | 承認担当者（個人指定の場合） |
| instructions | string | - | 承認者への指示 |

#### 承認担当の指定方法
- **ロール指定**: `responsible_role` にロール名を設定（例: `admin`, `manager`）
- **個人指定**: `responsible_user_id` に特定ユーザーを設定
- いずれか一方を設定（両方設定時はユーザー優先）

### 3. 最終承認通知設定（管理者機能）

#### WorkflowCategoryNotification
最終承認時に通知するロールを設定。

| 項目名 | 型 | 必須 | 説明 |
|--------|-----|------|------|
| workflow_category_id | reference | ◯ | 対象カテゴリ |
| role | string | ◯ | 通知先ロール |

---

## 4. 申請（ユーザー機能）

### WorkflowRequest
申請の本体。

#### 基本項目
| 項目名 | 型 | 必須 | 説明 |
|--------|-----|------|------|
| workflow_category_id | reference | ◯ | 申請カテゴリ |
| requester_id | reference | ◯ | 申請者（User） |
| requester_employee_id | reference | ◯ | 申請者（Employee） |
| title | string | ◯ | 件名 |
| status | string | ◯ | ステータス |
| amount | decimal | - | 金額 |
| currency | string | ◯ | 通貨（デフォルト: JPY） |
| vendor_name | string | - | 取引先名 |
| vehicle_identifier | string | - | 対象車両 |
| needed_on | date | - | 希望日 |
| summary | text | - | 概要 |
| additional_information | text | - | 補足情報 |
| metadata | jsonb | ◯ | カテゴリ別追加項目 |
| submitted_at | datetime | - | 申請日時 |
| finalized_at | datetime | - | 完了日時 |

#### ステータス
| ステータス | 説明 |
|------------|------|
| draft | 下書き |
| pending | 申請中（承認待ち） |
| approved | 承認済み |
| rejected | 却下 |
| returned | 差し戻し |
| cancelled | キャンセル |

#### 添付ファイル
- Active Storage使用: `has_many_attached :documents`
- 複数ファイル添付可

### 5. カテゴリ別メタデータ項目

`metadata` JSONBカラムに格納される、カテゴリ固有の入力項目。

#### 出張申請（travel）
| キー | ラベル | 型 |
|------|--------|-----|
| travel_destination | 訪問先 | text |
| travel_purpose | 目的 | textarea |
| travel_start_on | 出発日 | date |
| travel_end_on | 帰着日 | date |
| travel_members | 同行者 | text |
| travel_transport | 移動手段 | text |

#### 購買申請（purchase）
| キー | ラベル | 型 |
|------|--------|-----|
| purchase_items | 購入品目 | textarea |
| purchase_reason | 購入理由 | textarea |
| purchase_supplier | 仕入先候補 | text |
| purchase_expected_on | 納品希望日 | date |

#### 修繕申請（repair）
| キー | ラベル | 型 |
|------|--------|-----|
| repair_vehicle | 対象車両 | text |
| repair_issue | 故障内容 | textarea |
| repair_estimate_number | 見積番号 | text |
| repair_cost_center | 費用負担部署 | text |

#### チャレンジ申請（challenge）
| キー | ラベル | 型 |
|------|--------|-----|
| challenge_summary | 取り組み内容 | textarea |
| challenge_benefit | 期待効果 | textarea |
| challenge_team | 関係メンバー | text |

#### 資産・備品申請（asset）
| キー | ラベル | 型 |
|------|--------|-----|
| asset_item | 資産・備品名 | text |
| asset_current_location | 現在の場所 | text |
| asset_new_location | 移動/売却先 | text |
| asset_reason | 理由 | textarea |

#### 事故報告（incident）
| キー | ラベル | 型 |
|------|--------|-----|
| incident_datetime | 発生日時 | datetime |
| incident_location | 発生場所 | text |
| incident_description | 状況詳細 | textarea |
| incident_response | 初動対応 | textarea |
| incident_cost_impact | 想定損害/費用 | text |

#### 休暇申請（leave）
| キー | ラベル | 型 |
|------|--------|-----|
| leave_type | 休暇種別 | text |
| leave_start_on | 開始日 | date |
| leave_end_on | 終了日 | date |
| leave_days | 日数 | text |
| leave_reason | 理由 | textarea |

**休暇種別例**:
- 有給休暇
- 特別休暇（慶弔）
- 産前産後休暇
- 育児休暇
- 介護休暇
- その他

---

## 6. 承認ステージ

### WorkflowStage
申請ごとに作成される承認ステージ。申請時にテンプレートからコピーされる。

| 項目名 | 型 | 必須 | 説明 |
|--------|-----|------|------|
| workflow_request_id | reference | ◯ | 対象申請 |
| position | integer | ◯ | 承認順序 |
| name | string | ◯ | ステージ名 |
| status | string | ◯ | ステータス |
| responsible_role | string | - | 承認担当ロール |
| responsible_user_id | reference | - | 承認担当者 |
| activated_at | datetime | - | アクティブ化日時 |
| completed_at | datetime | - | 完了日時 |
| last_comment | text | - | 最新コメント |

#### ステージステータス
| ステータス | 説明 |
|------------|------|
| pending | 待機中（前ステージが未完了） |
| active | アクティブ（承認待ち） |
| approved | 承認済み |
| rejected | 却下 |
| returned | 差し戻し |
| held | 保留 |

---

## 7. 承認アクション

### WorkflowApproval
承認者のアクション履歴。

| 項目名 | 型 | 必須 | 説明 |
|--------|-----|------|------|
| workflow_stage_id | reference | ◯ | 対象ステージ |
| actor_id | reference | ◯ | 実行者 |
| action | string | ◯ | アクション種別 |
| comment | text | - | コメント |
| acted_at | datetime | ◯ | 実行日時 |

#### アクション種別
| アクション | 説明 | 申請への影響 |
|------------|------|--------------|
| approved | 承認 | 次ステージへ or 最終承認 |
| rejected | 却下 | 申請終了（rejected） |
| returned | 差し戻し | 申請者に戻す（returned） |
| held | 保留 | ステータス維持、コメント記録 |

---

## 8. コメント機能

### WorkflowNote
申請へのコメント（承認アクションとは別）。

| 項目名 | 型 | 必須 | 説明 |
|--------|-----|------|------|
| workflow_request_id | reference | ◯ | 対象申請 |
| author_id | reference | ◯ | 投稿者 |
| body | text | ◯ | コメント本文 |

---

## 承認フロー

### フロー図

```
[下書き] → [申請] → [ステージ1承認待ち] → [ステージ2承認待ち] → ... → [最終承認]
              ↓              ↓                    ↓
          [キャンセル]    [差し戻し]           [却下]
                            ↓
                       [申請者修正]
                            ↓
                       [再申請]
```

### 処理詳細

1. **申請作成**: ステータス `draft`、ステージテンプレートからステージをコピー
2. **申請提出**: ステータス `pending`、最初のステージを `active` に
3. **承認**: 次ステージを `active` に。最終ステージなら申請を `approved` に
4. **差し戻し**: 申請を `returned` に。申請者が修正後に再申請可能
5. **却下**: 申請を `rejected` に。終了
6. **保留**: ステージ・申請のステータス維持、コメントのみ記録

---

## 画面構成

### ユーザー向け

| 画面 | パス | 説明 |
|------|------|------|
| 申請一覧 | /workflows | 自分の申請一覧 |
| 新規申請 | /workflows/new | 申請作成 |
| 申請詳細 | /workflows/:id | 申請内容・承認状況の確認 |

### 管理者向け

| 画面 | パス | 説明 |
|------|------|------|
| 承認一覧 | /admin/workflow_requests | 全申請一覧・承認操作 |
| 申請詳細 | /admin/workflow_requests/:id | 詳細確認・承認操作 |
| カテゴリ一覧 | /admin/workflow_categories | カテゴリ管理 |
| カテゴリ編集 | /admin/workflow_categories/:id | ステージテンプレート・通知設定 |

---

## データモデル（ER図概要）

```
WorkflowCategory
  ├── has_many :stage_templates (WorkflowStageTemplate)
  ├── has_many :notifications (WorkflowCategoryNotification)
  └── has_many :workflow_requests

WorkflowRequest
  ├── belongs_to :workflow_category
  ├── belongs_to :requester (User)
  ├── belongs_to :requester_employee (Employee)
  ├── has_many :stages (WorkflowStage)
  ├── has_many :approvals (through :stages)
  ├── has_many :notes (WorkflowNote)
  └── has_many_attached :documents

WorkflowStage
  ├── belongs_to :workflow_request
  ├── belongs_to :responsible_user (User, optional)
  └── has_many :approvals (WorkflowApproval)

WorkflowApproval
  ├── belongs_to :workflow_stage
  └── belongs_to :actor (User)

WorkflowNote
  ├── belongs_to :workflow_request
  └── belongs_to :author (User)
```

---

## 実装状況

### 実装済み
- 基本的なCRUD（申請作成・一覧・詳細）
- 多段階承認フロー
- 承認・差し戻し・却下・保留アクション
- カテゴリ管理（管理者）
- ステージテンプレート設定
- 最終承認通知設定
- ファイル添付
- コメント機能
- カテゴリ別メタデータ入力

### 未実装・検討中
- メール/プッシュ通知の実装（現在はログ出力のみ）
- 代理承認機能
- 承認期限・リマインダー
- 申請のコピー機能
- 一括承認

---

## 備考

- マルチテナント対応（TenantScoped）
- 全モデルにtenant_idが紐づく
