# 配車機能 要件定義書

## 概要

### 目的
- 配車担当者が効率的に車両・ドライバーを配置できるUIを提供
- 2024年問題（改善基準告示）への準拠を配車時点でチェック
- 日報・請求との連携による業務効率化

### 関連機能
- 人事機能（ドライバー情報、勤怠、2024年問題）
- 車両管理（車両情報、整備状況）
- 日報機能（運行実績、デジタコ連携）
- 請求機能（タリフ、請求書発行）

---

## 1. 画面構成

```
配車
├─ 配車ボード（メイン画面）
│   ├─ タイムライン表示
│   ├─ ドライバー/車両の稼働可否表示
│   └─ ドラッグ&ドロップ配車
├─ 運行一覧
├─ 運行詳細・編集
├─ 運行指示書出力
├─ 荷主向け確認ページ（外部公開）
└─ マスタ管理
    ├─ 届け先台帳
    ├─ 拠点間距離・時間
    ├─ 傭車先
    └─ タリフ
```

---

## 2. 配車ボード

### 2-1. 概要

FullCalendar風のタイムラインUIで、車両×時間軸またはドライバー×時間軸で配車状況を可視化。

### 2-2. 表示モード

| モード | 説明 |
|--------|------|
| 車両基準 | Y軸に車両、X軸に時間を配置 |
| ドライバー基準 | Y軸にドライバー、X軸に時間を配置 |

### 2-3. 表示期間

- 日表示（デフォルト）
- 週表示
- 月表示（概要のみ）

### 2-4. グルーピング

| グループ | 説明 |
|----------|------|
| 荷主別 | 荷主ごとに車両/ドライバーをグループ化 |
| 商品別 | 取扱商品ごとにグループ化 |
| 営業所別 | 所属営業所ごとにグループ化 |
| 全体表示 | グループ化なし |

### 2-5. 稼働可否表示

#### 車両の状態

| 状態 | 表示 | 配車可否 |
|------|------|----------|
| 稼働可 | 通常表示 | ○ |
| 車検切れ | 赤背景 | × |
| 点検予定 | 黄背景 | △（警告付きで可） |
| 故障中 | グレーアウト | × |
| 整備予約 | 黄背景 | △（警告付きで可） |

#### ドライバーの状態

| 状態 | 表示 | 配車可否 |
|------|------|----------|
| 稼働可 | 通常表示 | ○ |
| 有給休暇 | 青背景 | × |
| 公休 | グレー背景 | × |
| 欠勤 | 赤背景 | × |
| 研修・会議 | 黄背景 | × |
| 免許更新中 | 赤背景 | × |
| 2024年問題警告 | オレンジ枠 | △（警告表示） |
| 出禁（届け先別） | - | △（該当届け先のみ×） |

### 2-6. ドラッグ&ドロップ操作

```
操作フロー:
1. 届け先の「箱」をドラッグ
2. タイムライン上の車両/ドライバー行にドロップ
3. 時間・積載量を確認するダイアログ表示
4. 確定で配車登録
```

### 2-7. 情報表示

タイムライン上の配車ブロックに表示する情報:

- 届け先名（省略表示）
- 時間指定有無（アイコン）
- 積載率（バー表示）
- 傭車の場合は色分け

---

## 3. 運行データモデル

### 3-1. 運行（Dispatch）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| dispatch_date | date | 配車日 |
| vehicle_id | reference | 車両（nullable: 傭車の場合） |
| driver_id | reference | ドライバー（nullable: 傭車の場合） |
| subcontractor_id | reference | 傭車先（nullable: 自社の場合） |
| subcontractor_vehicle | string | 傭車車両番号 |
| subcontractor_driver | string | 傭車ドライバー名 |
| status | enum | ステータス |
| rotation_number | integer | 回転数（1回転目、2回転目...） |
| is_overnight_loading | boolean | 宵積みフラグ |
| is_two_man_operation | boolean | 2マン運行フラグ |
| second_driver_id | reference | 2人目ドライバー |
| is_vehicle_sleep | boolean | 車中泊フラグ |
| estimated_revenue | decimal | 概算売上 |
| notes | text | 備考 |
| created_by_id | reference | 作成者 |

**ステータス**:
- draft: 仮配車
- confirmed: 確定
- in_progress: 運行中
- completed: 完了
- cancelled: キャンセル

### 3-2. 運行明細（DispatchStop）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| dispatch_id | reference | 運行 |
| stop_type | enum | 停車種別（pickup/delivery） |
| destination_id | reference | 届け先 |
| sequence | integer | 順序 |
| scheduled_arrival | datetime | 予定到着時刻 |
| scheduled_departure | datetime | 予定出発時刻 |
| time_window_start | time | 時間指定開始 |
| time_window_end | time | 時間指定終了 |
| is_time_specified | boolean | 時間指定有無 |
| quantity | decimal | 数量 |
| quantity_unit | string | 単位（個、ケース、パレット等） |
| weight_kg | decimal | 重量（kg） |
| volume_m3 | decimal | 容積（m³） |
| cargo_type | string | 積荷種別 |
| temperature_zone | enum | 温度帯（ambient/chilled/frozen） |
| shipper_id | reference | 荷主 |
| notes | text | 停車地備考（当日限り） |
| actual_arrival | datetime | 実績到着時刻 |
| actual_departure | datetime | 実績出発時刻 |

### 3-3. 届け先（Destination）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| code | string | 届け先コード |
| name | string | 届け先名 |
| name_kana | string | 届け先名（カナ） |
| address | string | 住所 |
| latitude | decimal | 緯度 |
| longitude | decimal | 経度 |
| phone | string | 電話番号 |
| contact_person | string | 担当者名 |
| default_notes | text | デフォルト注意事項 |
| operating_hours_start | time | 営業開始時間 |
| operating_hours_end | time | 営業終了時間 |
| closed_days | string | 定休日（曜日等） |
| shipper_id | reference | 所属荷主 |
| active | boolean | 有効フラグ |

### 3-4. 届け先注意事項（DestinationNote）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| destination_id | reference | 届け先 |
| note_type | enum | 種別 |
| content | text | 内容 |
| priority | integer | 表示優先度 |
| valid_from | date | 有効開始日 |
| valid_until | date | 有効終了日 |
| created_by_id | reference | 作成者 |

**種別**:
- permanent: 恒久的な注意事項
- temporary: 一時的な注意事項
- seasonal: 季節的な注意事項

### 3-5. 拠点間距離・時間（RouteDistance）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| origin_type | string | 出発地種別（depot/destination） |
| origin_id | integer | 出発地ID |
| destination_type | string | 到着地種別 |
| destination_id | integer | 到着地ID |
| distance_km | decimal | 距離（km） |
| duration_minutes | integer | 所要時間（分） |
| toll_cost | decimal | 高速料金 |
| route_type | enum | ルート種別（highway/general） |

### 3-6. 傭車先（Subcontractor）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| code | string | 傭車先コード |
| name | string | 傭車先名 |
| contact_person | string | 担当者名 |
| phone | string | 電話番号 |
| email | string | メールアドレス |
| fax | string | FAX番号 |
| address | string | 住所 |
| payment_terms | string | 支払条件 |
| notes | text | 備考 |
| active | boolean | 有効フラグ |

### 3-7. 傭車単価（SubcontractorRate）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| subcontractor_id | reference | 傭車先 |
| route_pattern | string | ルートパターン |
| vehicle_type | string | 車種 |
| rate | decimal | 単価 |
| rate_type | enum | 単価種別（per_trip/per_km/per_hour） |
| valid_from | date | 有効開始日 |
| valid_until | date | 有効終了日 |

### 3-8. 出禁情報（DriverBan）

| 項目名 | 型 | 説明 |
|--------|-----|------|
| driver_id | reference | ドライバー |
| destination_id | reference | 届け先（nullable: 全面出禁の場合） |
| shipper_id | reference | 荷主（nullable） |
| reason | text | 理由 |
| banned_at | date | 出禁開始日 |
| lifted_at | date | 解除日（nullable） |
| is_active | boolean | 有効フラグ |

---

## 4. 積載情報

### 4-1. 車両キャパシティ

車両マスタに以下を追加:

| 項目名 | 型 | 説明 |
|--------|-----|------|
| max_weight_kg | decimal | 最大積載重量（kg） |
| max_volume_m3 | decimal | 最大容積（m³） |
| max_pallets | integer | 最大パレット数 |

### 4-2. 積載率計算

```ruby
class LoadCalculator
  def calculate_load_rate(dispatch)
    stops = dispatch.dispatch_stops.where(stop_type: 'delivery')

    total_weight = stops.sum(:weight_kg)
    total_volume = stops.sum(:volume_m3)

    weight_rate = (total_weight / dispatch.vehicle.max_weight_kg * 100).round(1)
    volume_rate = (total_volume / dispatch.vehicle.max_volume_m3 * 100).round(1)

    {
      weight_rate: weight_rate,
      volume_rate: volume_rate,
      max_rate: [weight_rate, volume_rate].max,
      is_overloaded: weight_rate > 100 || volume_rate > 100
    }
  end
end
```

### 4-3. 過積載警告

- 積載率100%超: 配車不可（エラー）
- 積載率90%超: 警告表示
- 積載率表示: 配車ブロック上にバー表示

---

## 5. 2024年問題対応

### 5-1. 配車時バリデーション

配車確定時に以下をチェック:

| チェック項目 | 基準値 | 警告/エラー |
|--------------|--------|-------------|
| 1日拘束時間 | 13時間（例外あり） | 超過で警告 |
| 月間拘束時間 | 284時間 | 残り少ないと警告 |
| 休息期間 | 9時間以上 | 不足でエラー |
| 連続運転時間 | 4時間 | 超過で警告 |
| 時間外労働 | 月45時間 | 接近で警告 |

### 5-2. 警告解除

```
警告が出た場合:
1. 警告内容を表示
2. 「理由を入力して強制確定」ボタン
3. 理由入力ダイアログ
4. 解除理由を記録して配車確定

記録内容:
- 解除日時
- 解除者
- 解除理由（予期しない事象、長距離特例等）
```

### 5-3. ドライバー選択時の情報表示

```
ドライバー選択時に表示:
┌─────────────────────────────────────────────────┐
│ 田中 太郎                                       │
│ ─────────────────────────────────────────────── │
│ 今月拘束: 245h / 284h（残39h）                  │
│ 年累計時間外: 720h / 960h（残240h）             │
│ 前回休息: 10h                                   │
│ 本日稼働可能: 最大13h                           │
│ ─────────────────────────────────────────────── │
│ ⚠️ 今月あと39時間で上限到達                    │
└─────────────────────────────────────────────────┘
```

---

## 6. 特殊運行

### 6-1. 宵積み

- 翌日分の荷物を前日に積み込む
- タイムライン上で翌日にまたがる表現
- 積込日と配送日を別々に管理

### 6-2. 2マン運行

- 2人目ドライバーを指定
- 改善基準告示の特例（最大20〜28時間）適用
- 両ドライバーの労働時間を計算

### 6-3. 車中泊

- 車中泊フラグをON
- 休息期間の計算に反映
- 翌日の拘束時間開始を調整

---

## 7. 運行指示書

### 7-1. 出力形式

- PDF出力（印刷用）
- LINE送信（ドライバーへ直接）
- メール送信

### 7-2. 記載内容

| セクション | 内容 |
|------------|------|
| 基本情報 | 日付、車両番号、ドライバー名 |
| 行程 | 届け先リスト（順序付き） |
| 各届け先 | 住所、時間指定、積荷情報 |
| 注意事項 | 届け先・荷主・当日の3階層 |
| 連絡先 | 届け先電話番号、会社連絡先 |

### 7-3. 注意事項の階層

```
優先度（上が高い）:
1. 当日の特記事項（DispatchStop.notes）
2. 荷主の注意事項
3. 届け先の恒久的注意事項（Destination.default_notes）
4. 届け先の一時的注意事項（DestinationNote）
```

---

## 8. 荷主向け確認ページ

### 8-1. 概要

荷主に配車状況を確認してもらうための専用ページ。URLを発行して共有。

### 8-2. アクセス制御

- トークン付きURL（例: `/dispatch/confirm/abc123xyz`）
- 有効期限設定可能
- 該当荷主の運行のみ表示

### 8-3. 情報マスキング

- 他荷主の運行は表示しない
- 他荷主の届け先は「他社配送」等でマスク
- 傭車の詳細情報はマスク

### 8-4. 将来拡張: セルフオーダー

```
将来的な機能:
- 荷主が空き枠を確認
- 午前便・午後便の仮押さえ
- 定期便のオーダー入力
```

---

## 9. 外部連携

### 9-1. デジタコ連携

| メーカー | 連携方式 | 取得データ |
|----------|----------|------------|
| 矢崎 | CSVインポート | 運行データ |
| 富士通 | API（要確認） | 運行データ |
| 日本無線 | CSVインポート | 運行データ |
| デンソー | CSVインポート | 運行データ |

**取得データ**:
- 出発・到着時刻
- 走行距離
- 運転時間・休憩時間
- 速度超過・急ブレーキ等イベント

### 9-2. 日報との突合

```
突合フロー:
1. デジタコデータ取込
2. 配車データとマッチング（車両×日付）
3. 差異検出（予定 vs 実績）
4. 差異がある場合は確認・修正
5. 日報確定
```

### 9-3. 天気・交通情報表示（将来）

- 気象庁API連携
- JARTIC API連携
- 配車画面上にアイコン表示

---

## 10. 傭車管理

### 10-1. 配車時の傭車選択

- 自社車両が埋まっている場合に傭車を選択
- 傭車は視覚的に区別（別色表示）
- 傭車コストを自動計算

### 10-2. 傭車への運行指示

| 方式 | 説明 |
|------|------|
| FAX送信 | 運行指示書をFAX |
| メール送信 | PDFを添付してメール |
| LINE送信 | 担当者LINEへ送信 |

### 10-3. 傭車費用管理

- 傭車単価マスタから自動計算
- 売上との差益表示
- 月次での傭車費用集計

---

## 11. 売上・請求連携

### 11-1. タリフからの概算売上

```
配車時の売上計算:
1. 荷主×届け先×車種でタリフを検索
2. 数量・重量を乗じて概算売上算出
3. 配車画面上に表示
```

### 11-2. 日報との消し込み

```
消し込みフロー:
1. 配車データ（予定）
2. 日報データ（実績）
3. 差異があれば調整
4. 確定後、請求データに反映
```

### 11-3. 請求書出力（将来）

- 荷主別月次請求
- 運行明細付き
- PDF/Excel出力

---

## 12. AI配車（将来）

### 12-1. 概要

荷主からのオーダーを受け、AIが配車の仮決めを提案。

### 12-2. 最適化要素

| 要素 | 説明 |
|------|------|
| 労働時間均等化 | ドライバー間の労働時間を平準化 |
| 良い仕事の公平配分 | 高単価案件を特定ドライバーに偏らせない |
| 2024年問題準拠 | 改善基準告示を自動で考慮 |
| 積載効率 | 積み合わせの最適化 |
| ルート最適化 | 巡回順序の最適化 |

### 12-3. 提案→承認フロー

```
1. オーダー受付
2. AIが配車案を生成
3. 配車担当者がレビュー
4. 必要に応じて修正
5. 確定
```

---

## 13. 実装優先度

### Phase 1（MVP）
1. 配車ボード基本UI（タイムライン表示）
2. 運行CRUD（作成・編集・削除）
3. 届け先マスタ
4. ドライバー・車両の稼働可否表示
5. 運行指示書PDF出力

### Phase 2（基本機能）
6. ドラッグ&ドロップ配車
7. 積載情報・過積載警告
8. 拠点間距離・時間マスタ
9. 2024年問題バリデーション（基本）
10. 運行指示書LINE送信

### Phase 3（特殊運行）
11. 宵積み対応
12. 2マン運行対応
13. 車中泊対応
14. 乗り回し（複数回転）

### Phase 4（傭車）
15. 傭車先マスタ
16. 傭車配車
17. 傭車単価・コスト計算
18. 傭車への指示送信

### Phase 5（外部連携）
19. デジタコCSVインポート
20. 日報との突合
21. 荷主向け確認ページ

### Phase 6（売上・請求）
22. タリフマスタ
23. 概算売上計算
24. 日報との消し込み
25. 請求書出力

### Phase 7（高度化）
26. 2024年問題バリデーション（例外条件）
27. 出禁ドライバー管理
28. 交通・天気情報表示

### Phase 8（AI配車）
29. AI配車提案
30. 最適化エンジン
31. 荷主セルフオーダー

---

## 14. 画面イメージ

### 14-1. 配車ボード

```
配車ボード                                    2024/12/27 (金)
[◀ 前日] [今日] [翌日 ▶]    [日/週/月]    [車両基準/ドライバー基準]
グループ: [荷主別▼]

       06:00   08:00   10:00   12:00   14:00   16:00   18:00   20:00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【荷主A】
千葉100あ1234    ████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
佐藤 太郎        ┃ A工場→B倉庫 ┃              ┃ C店舗 ┃
                  80%積載

品川200か5678    ░░░░░░░░████████████████████░░░░░░░░░░░░░░░░░░░░░░
田中 次郎                ┃ D工場→E倉庫→F店舗 ┃
                         70%積載

【荷主B】
足立300さ9012    ░░░░░░░░░░░░████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
山田 花子                    ┃ G倉庫 ┃

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
未配車リスト                    ドラッグして配車 ↑
┌──────────┬──────────┬──────────┬──────────┐
│ H店舗    │ I工場    │ J倉庫    │ K店舗    │
│ 10:00指定│ 午前中   │ 時間指定無│ 14:00指定│
│ 5パレット│ 3t      │ 10ケース │ 2パレット│
└──────────┴──────────┴──────────┴──────────┘
```

### 14-2. ドライバー選択ダイアログ

```
┌─────────────────────────────────────────────────────────────┐
│ ドライバー選択                                        [×]  │
├─────────────────────────────────────────────────────────────┤
│ 検索: [________________]  [稼働可のみ ☑]                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ✓ 佐藤 太郎                                                │
│   今月拘束: 245h/284h (残39h)  前回休息: 11h               │
│   ✅ 本日稼働可能                                          │
│                                                             │
│ ○ 田中 次郎                                                │
│   今月拘束: 278h/284h (残6h)   前回休息: 9h                │
│   ⚠️ 拘束時間残りわずか                                    │
│                                                             │
│ ○ 山田 花子                                                │
│   今月拘束: 190h/284h (残94h)  前回休息: 12h               │
│   ✅ 本日稼働可能                                          │
│                                                             │
│ ━ 鈴木 一郎                                                │
│   ❌ 本日有給休暇                                          │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                              [キャンセル] [選択]            │
└─────────────────────────────────────────────────────────────┘
```

---

## 15. データモデル（ER図概要）

```
Dispatch（運行）
  ├── belongs_to :vehicle
  ├── belongs_to :driver
  ├── belongs_to :subcontractor (optional)
  ├── belongs_to :second_driver (optional)
  ├── has_many :dispatch_stops
  └── has_many :compliance_overrides

DispatchStop（運行明細）
  ├── belongs_to :dispatch
  ├── belongs_to :destination
  └── belongs_to :shipper

Destination（届け先）
  ├── belongs_to :shipper
  └── has_many :destination_notes

DestinationNote（届け先注意事項）
  └── belongs_to :destination

RouteDistance（拠点間距離）
  └── polymorphic: origin, destination

Subcontractor（傭車先）
  └── has_many :subcontractor_rates

SubcontractorRate（傭車単価）
  └── belongs_to :subcontractor

DriverBan（出禁情報）
  ├── belongs_to :driver
  ├── belongs_to :destination (optional)
  └── belongs_to :shipper (optional)

ComplianceOverride（コンプライアンス警告解除）
  ├── belongs_to :dispatch
  └── belongs_to :overridden_by (User)
```

---

## 備考

- マルチテナント対応（TenantScoped）
- 配車ボードはTurbo Frames/Stimulus.jsで実装
- ドラッグ&ドロップはSortableJS or FullCalendar Schedulerを検討
- 2024年問題対応は人事機能（compliance_2024.md）と連携
- 日報機能は別途要件定義予定

---

## 今後の作業予定（備忘録）

### 次回作業: 配車管理ページの拡張
- **Tumix風タブ/メニュー追加**: 配車管理ページにタブまたはメニューを追加
  - 分析タブ: 配車効率、車両稼働率、ドライバー稼働状況などの分析
  - 売上速報タブ: 当日/週間/月間の売上速報、目標対比
  - 参考: Tumixの配車管理画面のUI
