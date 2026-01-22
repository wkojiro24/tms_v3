# 人事機能 要件定義書

## 概要

### 目的
- 社員情報の一元管理
- 勤怠・労務管理（KING OF TIME連携）
- 2024年問題対応のコンプライアンス監視
- 入退社・カレンダー管理

### メニュー構成

```
人事
├─ 社員一覧
├─ 社員詳細
├─ カレンダー（誕生日・入社記念日等）
├─ 入退社管理
├─ 勤怠（KING OF TIME連携）
├─ 2024年問題ダッシュボード
├─ 教育
├─ 雇用契約書
├─ 採用管理
├─ 給与グリッド（管理者のみ）
└─ マスタ管理（管理者のみ）
    ├─ 部門
    ├─ 職種
    ├─ 役職
    └─ 等級
```

---

## 1. 社員マスタ（Employee）

### 1-1. 基本項目

| 項目名 | カラム | 型 | 必須 | 説明 |
|--------|--------|-----|------|------|
| 社員番号 | employee_code | string | ◯ | 一意の社員コード |
| 姓 | last_name | string | - | |
| 名 | first_name | string | - | |
| 姓（カナ） | last_name_kana | string | - | |
| 名（カナ） | first_name_kana | string | - | |
| 氏名 | full_name | string | - | 自動生成 |
| 生年月日 | date_of_birth | date | - | カレンダー表示用 |
| 入社日 | hire_date | date | - | 入社記念日用 |
| メール | email | string | - | |
| 電話番号 | phone | string | - | |
| 現在ステータス | current_status | string | ◯ | active/on_leave/retired/terminated |
| 部門 | department_id | reference | - | |
| 職種 | job_category_id | reference | - | |
| 役職 | job_position_id | reference | - | |
| 等級 | grade_level_id | reference | - | |
| 申請可能フラグ | submit_enabled | boolean | - | ワークフロー申請可否 |
| 備考 | notes | text | - | |

### 1-2. 雇用契約情報（追加）

| 項目名 | カラム | 型 | 必須 | 説明 |
|--------|--------|-----|------|------|
| 雇用形態 | employment_type | string | ◯ | full_time/part_time/contract |
| 週所定労働時間 | weekly_hours | decimal | - | パートタイム用 |
| 1日所定労働時間 | daily_hours | decimal | - | |
| 労使協定適用 | has_labor_agreement | boolean | - | 2024年問題用 |
| 長距離特例可 | long_distance_enabled | boolean | - | |
| 2人乗務可 | two_driver_enabled | boolean | - | |

---

## 2. 関連モデル（実装済み）

### 2-1. 在籍状況履歴（EmployeeStatus）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| status | enum | active/on_leave/retired/terminated |
| effective_from | date | 開始日 |
| effective_to | date | 終了日（任意） |
| reason | string | 理由 |

### 2-2. 役職履歴（EmployeePosition）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| title | string | 役職名 |
| effective_from | date | 開始日 |
| effective_to | date | 終了日（任意） |

### 2-3. 配属履歴（EmployeeAssignment）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| department_name | string | 配属先 |
| effective_from | date | 開始日 |
| effective_to | date | 終了日（任意） |

### 2-4. 資格（EmployeeQualification）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| name | string | 資格名 |
| acquired_on | date | 取得日 |
| expires_on | date | 有効期限（任意） |
| certificate_number | string | 証書番号 |

**運送業で必要な資格例**:
- 大型自動車免許
- けん引免許
- 危険物取扱者（乙種4類等）
- 運行管理者
- 整備管理者
- フォークリフト運転技能

### 2-5. 評価履歴（EmployeeReview）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| evaluation_cycle_id | reference | 評価サイクル |
| grade_level_id | reference | 評価後等級 |
| evaluation_grade_id | reference | 評価ランク |
| reviewed_on | date | 評価日 |
| comments | text | コメント |

---

## 3. マスタテーブル（実装済み）

### 3-1. 部門（Department）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| code | string | 部門コード |
| name | string | 部門名 |
| description | text | 説明 |
| active | boolean | 有効フラグ |

### 3-2. 職種（JobCategory）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| code | string | 職種コード |
| name | string | 職種名（ドライバー、事務、整備等） |
| description | text | 説明 |
| active | boolean | 有効フラグ |

### 3-3. 役職（JobPosition）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| code | string | 役職コード |
| name | string | 役職名 |
| grade | integer | 職位グレード |
| active | boolean | 有効フラグ |

### 3-4. 等級（GradeLevel）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| code | string | 等級コード |
| name | string | 等級名 |
| description | text | 説明 |
| active | boolean | 有効フラグ |

---

## 4. 給与管理（実装済み）

### 4-1. 給与セル（PayrollCell）

Excelからインポートした給与データを格納。

| 項目名 | 型 | 説明 |
|--------|-----|------|
| period_id | reference | 対象期間 |
| employee_id | reference | 対象社員 |
| item_id | reference | 給与項目 |
| payroll_batch_id | reference | インポートバッチ |
| location | string | 拠点 |
| value | decimal | 金額 |

### 4-2. 給与グリッド画面（/admin/payrolls）

- 期間×社員×項目のマトリクス表示
- 拠点別フィルタ
- ページネーション

---

## 5. 入退社管理（新規）

### 5-1. 機能概要

| 機能 | 説明 |
|------|------|
| 入社予定者リスト | 入社日が未来の社員一覧 |
| 退社予定者リスト | 退社予定日が設定されている社員一覧 |
| 入退社履歴 | 過去の入社・退社履歴 |
| オンボーディング | 入社時のタスク管理（将来） |

### 5-2. 想定データモデル

**EmployeeOnboarding（入社手続き）**

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| scheduled_date | date | 入社予定日 |
| status | enum | pending/in_progress/completed |
| tasks | jsonb | チェックリスト |

**EmployeeOffboarding（退社手続き）**

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| scheduled_date | date | 退社予定日 |
| reason | string | 退社理由 |
| status | enum | pending/in_progress/completed |
| tasks | jsonb | チェックリスト |

---

## 6. カレンダー（新規）

### 6-1. 表示内容

| イベント種別 | 説明 |
|--------------|------|
| 誕生日 | 社員の誕生日 |
| 入社記念日 | 入社日から○年 |
| 資格有効期限 | 免許・資格の期限 |
| 有給取得予定 | 承認済み休暇申請（将来） |
| 研修予定 | 研修スケジュール（将来） |

### 6-2. 画面イメージ

```
2025年1月
┌───┬───┬───┬───┬───┬───┬───┐
│日 │月 │火 │水 │木 │金 │土 │
├───┼───┼───┼───┼───┼───┼───┤
│   │   │   │ 1 │ 2 │ 3 │ 4 │
│   │   │   │   │   │   │   │
├───┼───┼───┼───┼───┼───┼───┤
│ 5 │ 6 │ 7 │ 8 │ 9 │10 │11 │
│   │   │🎂 │   │   │🎂 │   │
│   │   │田中│   │   │鈴木│   │
├───┼───┼───┼───┼───┼───┼───┤
│12 │13 │14 │15 │16 │17 │18 │
│🎉 │   │   │⚠️ │   │   │   │
│佐藤│   │   │免許│   │   │   │
│入社│   │   │期限│   │   │   │
└───┴───┴───┴───┴───┴───┴───┘

凡例: 🎂誕生日  🎉入社記念日  ⚠️期限
```

### 6-3. アラート機能

| アラート | タイミング |
|----------|------------|
| 誕生日 | 当日 |
| 入社記念日 | 当日 |
| 資格期限 | 30日前、7日前、当日 |

---

## 7. 勤怠管理（KING OF TIME連携）

### 7-1. 連携データ

| 項目 | 説明 |
|------|------|
| 出勤時刻 | 勤務開始 |
| 退勤時刻 | 勤務終了 |
| 休憩時間 | 休憩合計 |
| 実労働時間 | 出勤〜退勤 - 休憩 |
| 時間外労働 | 所定時間超過分 |
| 深夜労働 | 22:00〜5:00の労働 |
| 休日労働 | 休日出勤 |
| 有給取得 | 有給消化日数 |
| 有給残日数 | 残りの有給 |

### 7-2. 連携方式

**Phase 1: CSVインポート**
- KING OF TIMEからエクスポートしたCSVを手動インポート
- 日次または月次

**Phase 2: API連携**
- KING OF TIME APIを利用した自動連携
- リアルタイムまたは定期同期

### 7-3. 想定データモデル

**AttendanceRecord（勤怠記録）**

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| work_date | date | 勤務日 |
| clock_in | datetime | 出勤時刻 |
| clock_out | datetime | 退勤時刻 |
| break_minutes | integer | 休憩時間（分） |
| work_minutes | integer | 実労働時間（分） |
| overtime_minutes | integer | 時間外労働（分） |
| late_night_minutes | integer | 深夜労働（分） |
| holiday_work | boolean | 休日出勤 |
| paid_leave_used | decimal | 有給使用（日） |
| source | string | データソース（kot/manual） |
| imported_at | datetime | インポート日時 |

**AttendanceSummary（勤怠月次サマリー）**

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| year | integer | 年 |
| month | integer | 月 |
| work_days | integer | 出勤日数 |
| total_work_hours | decimal | 総労働時間 |
| total_overtime_hours | decimal | 時間外労働計 |
| total_late_night_hours | decimal | 深夜労働計 |
| holiday_work_days | integer | 休日出勤日数 |
| paid_leave_used | decimal | 有給使用日数 |
| paid_leave_remaining | decimal | 有給残日数 |

---

## 8. 教育（新規）

### 8-1. 概要

外部コンテンツ（マナビDX、トラック協会研修等）の視聴管理と、社内確認テストを提供。

| 機能 | 説明 |
|------|------|
| コース管理 | 教育コンテンツを登録・管理 |
| 受講義務割当 | 対象者と期限を設定 |
| 進捗管理 | 受講状況の追跡 |
| 確認テスト | 理解度確認の4択クイズ |

### 8-2. コース（Course）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| title | string | コース名 |
| description | text | 説明 |
| content_type | enum | external_link/video/document |
| content_url | string | 外部リンクURL（マナビDX等） |
| target_audience | string | 対象者種別（driver/manager/all等） |
| category | string | カテゴリ（safety/compliance/skill等） |
| estimated_minutes | integer | 想定受講時間（分） |
| has_quiz | boolean | 確認テストの有無 |
| passing_score | integer | 合格点（%） |
| active | boolean | 有効フラグ |

**コンテンツ種別**:
- external_link: 外部サイトへのリンク（マナビDX、トラック協会等）
- video: YouTube/Vimeo埋め込み
- document: PDF資料

### 8-3. 受講義務（CourseAssignment）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| course_id | reference | 対象コース |
| assignee_type | string | 割当種別（employee/department/job_category） |
| assignee_id | integer | 割当先ID |
| due_date | date | 受講期限 |
| required | boolean | 必須/任意 |
| assigned_by_id | reference | 割当者 |

**割当パターン**:
- 個人指定: 特定の社員に割当
- 部門指定: 部門全員に割当（所長研修など）
- 職種指定: 職種全員に割当（ドライバー全員など）

### 8-4. 受講履歴（CourseEnrollment）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| course_id | reference | 対象コース |
| employee_id | reference | 受講者 |
| assignment_id | reference | 割当（任意） |
| status | enum | not_started/in_progress/completed/failed |
| started_at | datetime | 受講開始日時 |
| completed_at | datetime | 受講完了日時 |
| quiz_score | integer | テストスコア（%） |
| quiz_attempts | integer | テスト受験回数 |

### 8-5. 確認テスト（Quiz）

#### クイズ（Quiz）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| course_id | reference | 対象コース |
| title | string | テストタイトル |
| passing_score | integer | 合格点（%） |
| time_limit_minutes | integer | 制限時間（分、任意） |
| shuffle_questions | boolean | 問題順シャッフル |
| shuffle_choices | boolean | 選択肢シャッフル |

#### 問題（QuizQuestion）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| quiz_id | reference | 対象クイズ |
| question_type | enum | text/image/video |
| question_text | text | 問題文 |
| question_image_url | string | 問題画像URL（ドライバー向け） |
| explanation | text | 解説（回答後に表示） |
| position | integer | 表示順 |

**問題タイプ**:
- text: テキストのみの問題
- image: 画像付き問題（荷物の積み方、車両点検箇所等）
- video: 動画付き問題（危険予測等）

#### 選択肢（QuizChoice）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| question_id | reference | 対象問題 |
| choice_type | enum | text/image |
| choice_text | string | 選択肢テキスト |
| choice_image_url | string | 選択肢画像URL |
| is_correct | boolean | 正解フラグ |
| position | integer | 表示順 |

**選択肢タイプ**:
- text: テキスト選択肢
- image: 画像選択肢（正しい積み方はどれ？等）

### 8-6. ドライバー向け問題例

```
【画像問題】荷物の積み方
┌──────────────────────────────────────┐
│ [荷物が不安定に積まれた画像]        │
│                                      │
│ この積み方の問題点は何ですか？      │
│                                      │
│ ○ A. 荷物の高さが規定を超えている  │
│ ○ B. 固定ベルトの締め方が不十分    │
│ ○ C. 荷物の重心が偏っている        │
│ ○ D. 問題なし                      │
└──────────────────────────────────────┘

【画像選択問題】車両点検
┌──────────────────────────────────────┐
│ タイヤの溝の深さを確認する際、      │
│ 正しい測定方法はどれですか？        │
│                                      │
│ [A.画像] [B.画像] [C.画像] [D.画像] │
└──────────────────────────────────────┘

【シナリオ問題】接客対応
┌──────────────────────────────────────┐
│ 配送先で「伝票と中身が違う」と     │
│ クレームを受けました。              │
│ 最初にすべき対応はどれですか？      │
│                                      │
│ ○ A. その場で謝罪し持ち帰る        │
│ ○ B. 伝票を確認し会社に連絡する    │
│ ○ C. 「知りません」と言う          │
│ ○ D. 別の配達を優先する            │
└──────────────────────────────────────┘
```

### 8-7. 管理画面

#### コース管理（/hr/courses）

| 機能 | 説明 |
|------|------|
| コース一覧 | 登録コースの一覧 |
| コース登録 | 新規コース作成 |
| クイズ編集 | 問題の追加・編集 |
| 割当管理 | 対象者・期限設定 |

#### 受講状況（/hr/courses/:id/enrollments）

| 機能 | 説明 |
|------|------|
| 受講者一覧 | 完了/未完了のリスト |
| 進捗率 | コース全体の受講率 |
| 期限切れ | 期限を過ぎた未受講者 |

### 8-8. 受講者画面

```
マイ研修
┌──────────────────────────────────────────────────────┐
│ 必須コース（期限あり）                              │
├──────────────────────────────────────────────────────┤
│ 📚 2024年度 安全運転研修          期限: 1/31       │
│    [マナビDX] ⏱ 60分             [受講する]        │
│                                                      │
│ 📚 フォークリフト安全講習         期限: 2/15       │
│    [トラック協会] ⏱ 45分         [受講する]        │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ 完了済み                                            │
├──────────────────────────────────────────────────────┤
│ ✅ コンプライアンス基礎           完了: 12/15      │
│    テスト: 90点（合格）                              │
└──────────────────────────────────────────────────────┘
```

### 8-9. 受講フロー

```
1. コース選択
   ↓
2. 外部リンクで視聴（マナビDX等）
   ※ 自己申告で「視聴完了」をクリック
   ↓
3. 確認テスト（設定されている場合）
   - 4択問題を回答
   - 合格点以上で完了
   - 不合格の場合は再視聴・再受験
   ↓
4. 完了記録
   - 受講日時を記録
   - 管理者ダッシュボードに反映
```

---

## 9. 雇用契約書（新規）

### 9-1. 概要

社員ごとの雇用契約書をシステムで管理。契約更新のタイミングや条件変更の履歴を追跡。

| 機能 | 説明 |
|------|------|
| 契約書一覧 | 全社員の契約状況を一覧表示 |
| 契約書作成 | 新規契約書の作成 |
| 契約更新 | 期間満了前の更新処理 |
| 契約履歴 | 過去の契約内容を履歴管理 |
| PDF出力 | 契約書のPDF出力 |

### 9-2. 雇用契約（EmploymentContract）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employee_id | reference | 対象社員 |
| contract_type | enum | 契約種別（正社員/契約社員/パート/アルバイト） |
| start_date | date | 契約開始日 |
| end_date | date | 契約終了日（無期の場合はnull） |
| status | enum | ステータス（draft/active/expired/terminated） |
| renewal_type | enum | 更新区分（indefinite/fixed_term/auto_renewal） |
| work_location | string | 就業場所 |
| job_description | text | 業務内容 |
| working_hours_start | time | 始業時刻 |
| working_hours_end | time | 終業時刻 |
| break_minutes | integer | 休憩時間（分） |
| weekly_working_days | integer | 週所定労働日数 |
| weekly_working_hours | decimal | 週所定労働時間 |
| monthly_salary | decimal | 月給（月給制の場合） |
| hourly_rate | decimal | 時給（時給制の場合） |
| salary_type | enum | 給与形態（monthly/hourly/daily） |
| bonus_eligible | boolean | 賞与対象 |
| social_insurance | boolean | 社会保険加入 |
| employment_insurance | boolean | 雇用保険加入 |
| notes | text | 特記事項 |
| signed_at | datetime | 締結日時 |
| signed_by_employee | boolean | 社員署名済み |
| pdf_file | attachment | 契約書PDF |

**契約種別**:
- permanent: 正社員（無期雇用）
- contract: 契約社員（有期雇用）
- part_time: パートタイマー
- temporary: アルバイト

**更新区分**:
- indefinite: 無期（正社員等）
- fixed_term: 有期（更新なし）
- auto_renewal: 自動更新

### 9-3. 契約条件変更履歴（ContractAmendment）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| employment_contract_id | reference | 対象契約 |
| amendment_type | enum | 変更種別 |
| effective_date | date | 適用日 |
| field_name | string | 変更項目 |
| old_value | string | 変更前の値 |
| new_value | string | 変更後の値 |
| reason | text | 変更理由 |
| approved_by_id | reference | 承認者 |

**変更種別**:
- salary_change: 給与変更
- position_change: 役職変更
- hours_change: 勤務時間変更
- location_change: 勤務地変更
- renewal: 契約更新
- termination: 契約終了

### 9-4. 契約書テンプレート（ContractTemplate）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| name | string | テンプレート名 |
| contract_type | enum | 対象契約種別 |
| body | text | テンプレート本文（変数埋め込み） |
| active | boolean | 有効フラグ |

**テンプレート変数例**:
```
{{employee_name}} - 社員氏名
{{start_date}} - 契約開始日
{{end_date}} - 契約終了日
{{work_location}} - 就業場所
{{job_description}} - 業務内容
{{working_hours}} - 勤務時間
{{salary}} - 給与
{{company_name}} - 会社名
{{today}} - 本日の日付
```

### 9-5. 画面イメージ

#### 契約書一覧

```
雇用契約書一覧

フィルタ: [契約種別▼] [ステータス▼] [更新期限▼]

┌──────────────────────────────────────────────────────────────────┐
│ 社員名     │ 契約種別 │ 開始日    │ 終了日    │ ステータス │ 操作 │
├──────────────────────────────────────────────────────────────────┤
│ 佐藤 太郎  │ 正社員   │ 2020/04/01│ -        │ ✅ 有効    │ [詳細] │
│ 田中 次郎  │ 契約社員 │ 2024/04/01│ 2025/03/31│ ⚠️ 更新近 │ [詳細] │
│ 鈴木 花子  │ パート   │ 2023/10/01│ 2024/09/30│ ❌ 期限切れ│ [詳細] │
└──────────────────────────────────────────────────────────────────┘
```

#### 契約更新アラート

```
契約更新が必要な社員（30日以内）

┌──────────────────────────────────────────────────────┐
│ ⚠️ 田中 次郎                                        │
│    契約終了日: 2025/03/31（残り28日）               │
│    [更新する] [詳細を見る]                          │
├──────────────────────────────────────────────────────┤
│ ⚠️ 山田 一郎                                        │
│    契約終了日: 2025/04/15（残り43日）               │
│    [更新する] [詳細を見る]                          │
└──────────────────────────────────────────────────────┘
```

### 9-6. 契約書作成フロー

```
1. テンプレート選択
   - 契約種別に応じたテンプレートを選択
   ↓
2. 契約条件入力
   - 社員情報は自動入力
   - 給与・勤務条件を入力
   ↓
3. プレビュー
   - PDF形式でプレビュー確認
   ↓
4. 承認・締結
   - 管理者承認
   - 社員への通知（将来：電子署名）
   ↓
5. 保管
   - PDF保存
   - 履歴に記録
```

### 9-7. アラート条件

| アラート | タイミング | 通知先 |
|----------|------------|--------|
| 契約期限接近 | 60日前、30日前、14日前 | 人事担当者 |
| 契約期限切れ | 当日 | 人事担当者、上長 |
| 契約未締結 | 入社日の7日前 | 人事担当者 |
| 試用期間終了 | 終了30日前 | 人事担当者、上長 |

---

## 10. 採用管理（新規）

### 10-1. 概要

求人広告の管理と応募者の選考プロセスを追跡。

| 機能 | 説明 |
|------|------|
| 求人広告管理 | 掲載中の求人情報を一元管理 |
| 応募者管理 | 応募者情報と選考状況の追跡 |
| 選考プロセス | 面接スケジュール・評価管理 |
| 採用分析 | 媒体別の応募数・採用率の分析 |

### 10-2. 求人広告（JobPosting）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| title | string | 求人タイトル |
| job_category_id | reference | 職種 |
| department_id | reference | 配属部門 |
| employment_type | enum | 雇用形態（正社員/契約/パート等） |
| description | text | 仕事内容 |
| requirements | text | 応募資格 |
| salary_min | decimal | 給与下限 |
| salary_max | decimal | 給与上限 |
| salary_type | enum | 給与形態（月給/時給/年収） |
| work_location | string | 勤務地 |
| working_hours | string | 勤務時間 |
| benefits | text | 待遇・福利厚生 |
| status | enum | ステータス（draft/active/closed） |
| published_at | datetime | 公開日時 |
| closed_at | datetime | 募集終了日時 |
| headcount | integer | 募集人数 |

### 10-3. 求人掲載先（JobPostingChannel）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| job_posting_id | reference | 対象求人 |
| channel_type | enum | 掲載媒体種別 |
| channel_name | string | 媒体名 |
| external_url | string | 掲載URL |
| cost | decimal | 掲載費用 |
| start_date | date | 掲載開始日 |
| end_date | date | 掲載終了日 |
| status | enum | ステータス（scheduled/active/ended） |

**掲載媒体種別**:
- job_board: 求人サイト（Indeed、求人ボックス等）
- driver_specific: ドライバー専門（ドラEVER、トラックマン等）
- agency: 人材紹介会社
- referral: 社員紹介
- direct: 自社サイト
- other: その他

### 10-4. 応募者（Applicant）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| job_posting_id | reference | 応募求人 |
| channel_id | reference | 応募経路 |
| last_name | string | 姓 |
| first_name | string | 名 |
| last_name_kana | string | 姓（カナ） |
| first_name_kana | string | 名（カナ） |
| email | string | メールアドレス |
| phone | string | 電話番号 |
| date_of_birth | date | 生年月日 |
| address | string | 住所 |
| current_status | enum | 現在の状況（employed/unemployed/student） |
| resume_file | attachment | 履歴書 |
| cv_file | attachment | 職務経歴書 |
| licenses | text | 保有資格（大型免許等） |
| experience_years | integer | 運転経験年数 |
| desired_salary | decimal | 希望給与 |
| available_date | date | 入社可能日 |
| notes | text | 備考 |
| status | enum | 選考ステータス |
| applied_at | datetime | 応募日時 |

**選考ステータス**:
- new: 新規応募
- screening: 書類選考中
- interview_scheduled: 面接予定
- interview_completed: 面接完了
- offer: 内定
- accepted: 内定承諾
- rejected: 不採用
- withdrawn: 辞退

### 10-5. 面接（Interview）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| applicant_id | reference | 対象応募者 |
| interview_type | enum | 面接種別 |
| scheduled_at | datetime | 面接日時 |
| location | string | 面接場所 |
| interviewer_ids | array | 面接官（複数可） |
| status | enum | ステータス（scheduled/completed/cancelled） |
| overall_rating | integer | 総合評価（1-5） |
| comments | text | 面接メモ |

**面接種別**:
- phone: 電話面接
- online: オンライン面接
- onsite: 来社面接
- trial: 体験乗車

### 10-6. 画面イメージ

#### 求人広告一覧

```
求人広告管理

[+ 新規求人作成]

┌──────────────────────────────────────────────────────────────────────┐
│ 求人タイトル          │ 雇用形態 │ 応募数 │ 掲載媒体   │ ステータス │
├──────────────────────────────────────────────────────────────────────┤
│ 大型ドライバー（関東）│ 正社員   │ 12名   │ 3媒体      │ ✅ 掲載中  │
│ 4tドライバー（千葉）  │ 正社員   │ 5名    │ 2媒体      │ ✅ 掲載中  │
│ 倉庫作業スタッフ      │ パート   │ 8名    │ Indeed    │ ⏸ 一時停止│
└──────────────────────────────────────────────────────────────────────┘
```

#### 応募者パイプライン

```
応募者一覧 - 大型ドライバー（関東）

新規(3) → 書類選考(2) → 面接予定(1) → 面接完了(2) → 内定(1) → 採用(0)

┌──────────────────────────────────────────────────────────────────────┐
│ 氏名      │ 応募日    │ 経路      │ 経験   │ ステータス   │ 操作    │
├──────────────────────────────────────────────────────────────────────┤
│ 山田 太郎 │ 12/20    │ Indeed   │ 5年    │ 📋 新規     │ [詳細]  │
│ 佐藤 次郎 │ 12/18    │ ドラEVER │ 10年   │ 📅 面接予定 │ [詳細]  │
│ 鈴木 花子 │ 12/15    │ 社員紹介 │ 3年    │ ✅ 内定     │ [詳細]  │
└──────────────────────────────────────────────────────────────────────┘
```

#### 採用分析ダッシュボード

```
採用分析（2024年）

応募数推移                    媒体別効果
┌─────────────────┐          ┌────────────────────────┐
│     ___        │          │ Indeed    : 45名 (採用3)│
│    /   \       │          │ ドラEVER  : 32名 (採用5)│
│   /     \__    │          │ 社員紹介  : 12名 (採用4)│
│__/          \_ │          │ 自社サイト: 8名  (採用1)│
└─────────────────┘          └────────────────────────┘
1月  3月  6月  9月  12月

採用コスト: 1名あたり平均 ¥85,000
```

### 10-7. 採用から入社へのフロー

```
1. 内定承諾
   ↓
2. 入社日確定
   ↓
3. 社員マスタ作成（Applicant → Employee変換）
   ↓
4. 雇用契約書作成
   ↓
5. 入社手続き開始（オンボーディング）
```

### 10-8. 将来拡張：求人媒体API連携

| 媒体 | 連携内容 | 備考 |
|------|----------|------|
| Indeed | 求人掲載、応募者取込 | Employer API |
| 求人ボックス | 求人掲載 | XML連携 |
| ドラEVER | 求人掲載、応募者取込 | 要確認 |
| Engage | 求人掲載 | API連携可 |

**連携により実現できること**:
- 求人の一括掲載・更新
- 応募者情報の自動取込
- 掲載状況のリアルタイム把握
- 応募数・閲覧数の自動集計

---

## 11. 2024年問題ダッシュボード

詳細は [compliance_2024.md](compliance_2024.md) を参照。

### 11-1. 概要

- ドライバーの拘束時間・時間外労働を監視
- 例外条件を考慮した自動判定
- 配車画面への稼働可能時間表示

### 11-2. 人事画面での表示

```
2024年問題 コンプライアンス状況

全体: ✅ 95%クリア（警告3名 / 違反0名）

ドライバー別
┌────────────────────────────────────────────────────┐
│ 氏名      │ 月拘束  │ 年時間外 │ 休息 │ ステータス │
├────────────────────────────────────────────────────┤
│ 佐藤 太郎 │ 260h   │ 520h    │ 11h │ ✅ OK     │
│ 田中 次郎 │ 278h   │ 780h    │ 9h  │ ⚠️ 警告   │
└────────────────────────────────────────────────────┘

パートタイム
┌────────────────────────────────────────────────────┐
│ 氏名      │ 契約   │ 実績   │ 超過 │ ステータス  │
├────────────────────────────────────────────────────┤
│ 高橋 一郎 │ 20h/週 │ 22h   │ 2h  │ ⚠️ 超過    │
└────────────────────────────────────────────────────┘
```

---

## 12. 画面構成

### 12-1. 社員一覧（/employees）

| 機能 | 説明 |
|------|------|
| 一覧表示 | 社員番号、氏名、部門、役職、ステータス |
| フィルタ | 部門、職種、ステータス、雇用形態 |
| 検索 | 氏名、社員番号 |
| ソート | 社員番号、氏名、入社日 |

### 12-2. 社員詳細（/employees/:id）

| セクション | 内容 |
|------------|------|
| 基本情報 | 氏名、社員番号、連絡先、写真 |
| 雇用情報 | 雇用形態、入社日、部門、役職、等級 |
| 在籍履歴 | ステータス変更履歴 |
| 役職履歴 | 昇進・異動履歴 |
| 配属履歴 | 部署異動履歴 |
| 資格一覧 | 保有資格、有効期限 |
| 評価履歴 | 過去の評価 |
| 勤怠サマリー | 今月・年累計の労働時間 |
| 2024年問題 | コンプライアンス状況（ドライバーのみ） |

### 12-3. カレンダー（/hr/calendar）

| 機能 | 説明 |
|------|------|
| 月表示 | カレンダー形式でイベント表示 |
| イベント種別切替 | 誕生日、入社記念日、資格期限等 |
| 部門フィルタ | 特定部門のみ表示 |

### 12-4. 入退社管理（/hr/onboarding）

| 機能 | 説明 |
|------|------|
| 入社予定 | 入社予定者リスト |
| 退社予定 | 退社予定者リスト |
| 履歴 | 過去の入退社一覧 |

### 12-5. 勤怠（/hr/attendance）

| 機能 | 説明 |
|------|------|
| 日次一覧 | 指定日の全社員出退勤 |
| 月次サマリー | 月の勤怠集計 |
| CSVインポート | KING OF TIMEデータ取込 |

### 12-6. 教育（/hr/education）

| 機能 | 説明 |
|------|------|
| マイ研修 | 自分の受講コース一覧 |
| コース管理 | コース登録・編集（管理者） |
| 受講状況 | 進捗確認（管理者） |

### 12-7. 雇用契約書（/hr/contracts）

| 機能 | 説明 |
|------|------|
| 契約書一覧 | 全社員の契約状況 |
| 契約書作成 | 新規契約書の作成 |
| 契約更新 | 期間満了前の更新処理 |
| 更新アラート | 期限接近の通知 |

### 12-8. 採用管理（/hr/recruiting）

| 機能 | 説明 |
|------|------|
| 求人広告一覧 | 掲載中の求人管理 |
| 応募者一覧 | 応募者の選考状況 |
| 面接スケジュール | 面接日程の管理 |
| 採用分析 | 媒体別効果分析 |

### 12-9. 2024年問題（/hr/compliance）

| 機能 | 説明 |
|------|------|
| ダッシュボード | 全体のコンプライアンス状況 |
| ドライバー別 | 個人ごとの詳細 |
| アラート一覧 | 警告・違反のリスト |

---

## 13. データモデル（ER図概要）

```
Employee
  ├── has_one :user
  ├── belongs_to :department
  ├── belongs_to :job_category
  ├── belongs_to :job_position
  ├── belongs_to :grade_level
  ├── has_many :statuses (EmployeeStatus)
  ├── has_many :positions (EmployeePosition)
  ├── has_many :assignments (EmployeeAssignment)
  ├── has_many :qualifications (EmployeeQualification)
  ├── has_many :reviews (EmployeeReview)
  ├── has_many :payroll_cells
  ├── has_many :attendance_records
  ├── has_many :compliance_statuses
  └── has_many :course_enrollments

Department / JobCategory / JobPosition / GradeLevel
  └── マスタテーブル

AttendanceRecord
  └── belongs_to :employee

DriverComplianceStatus
  └── belongs_to :employee

Course（教育コース）
  ├── has_many :course_assignments
  ├── has_many :course_enrollments
  └── has_one :quiz

Quiz（確認テスト）
  ├── belongs_to :course
  └── has_many :quiz_questions

QuizQuestion（問題）
  ├── belongs_to :quiz
  └── has_many :quiz_choices

QuizChoice（選択肢）
  └── belongs_to :quiz_question

CourseAssignment（受講義務）
  └── belongs_to :course

CourseEnrollment（受講履歴）
  ├── belongs_to :course
  └── belongs_to :employee

EmploymentContract（雇用契約）
  ├── belongs_to :employee
  └── has_many :contract_amendments

ContractAmendment（契約変更履歴）
  └── belongs_to :employment_contract

ContractTemplate（契約書テンプレート）
  └── テンプレートマスタ

JobPosting（求人広告）
  ├── has_many :job_posting_channels
  └── has_many :applicants

JobPostingChannel（掲載先）
  └── belongs_to :job_posting

Applicant（応募者）
  ├── belongs_to :job_posting
  └── has_many :interviews

Interview（面接）
  └── belongs_to :applicant
```

---

## 14. 実装状況

### 実装済み
- 社員マスタ（Employee）
- 在籍・役職・配属・資格・評価の各履歴モデル
- マスタテーブル（部門、職種、役職、等級）
- 給与グリッド

### 未実装
- 社員一覧・詳細画面（現在はプレースホルダー）
- カレンダー
- 入退社管理
- 勤怠管理（KING OF TIME連携）
- 2024年問題ダッシュボード
- 教育（コース管理・確認テスト）
- 雇用契約書管理
- 採用管理（求人広告・応募者管理）
- 雇用契約情報の拡張

---

## 15. 実装優先度

### Phase 1（基本）
1. 社員一覧・詳細画面
2. 資格の有効期限管理
3. カレンダー（誕生日・入社記念日）

### Phase 2（勤怠）
4. 勤怠CSVインポート
5. 勤怠月次サマリー
6. 2024年問題ダッシュボード

### Phase 3（入退社）
7. 入退社管理
8. オンボーディングチェックリスト

### Phase 4（教育）
9. コース管理・受講義務割当
10. 確認テスト（4択クイズ）
11. 画像/動画問題対応

### Phase 5（雇用契約・採用）
12. 雇用契約書管理
13. 契約テンプレート・PDF出力
14. 求人広告管理
15. 応募者管理・選考プロセス
16. 採用分析ダッシュボード

### Phase 6（自動化）
17. KING OF TIME API連携
18. 資格期限アラート通知
19. 契約更新アラート

### Phase 7（求人媒体連携）
20. Indeed API連携
21. その他求人媒体連携

---

## 備考

- マルチテナント対応（TenantScoped）
- 車両マスタと同様の考え方（一覧→詳細）
- 2024年問題対応は配車機能と連携
- KING OF TIME連携は段階的に実装（CSV→API）
