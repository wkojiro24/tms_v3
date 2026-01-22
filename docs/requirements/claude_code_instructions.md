# Claude Code への指示書

## 実装する機能

**車両名寄せ機能**

詳細な要件定義は `docs/requirements/vehicle_normalization_requirements.md` を参照してください。

---

## 最初にやること

1. **要件定義を読む**
   ```
   docs/requirements/vehicle_normalization_requirements.md を読んでください
   ```

2. **既存コードを確認**
   - `db/schema.rb` で `vehicle_aliases` テーブルの構造を確認
   - `db/schema.rb` で `vehicles` テーブルの構造を確認
   - `lib/tasks/vehicles.rake` で既存のインポート処理を確認

---

## Phase 0-1: 名寄せエンジンの実装

### タスク1: UnmappedVehicleNumber テーブル作成

マイグレーションファイルを作成してください。

**テーブル構造:**
- tenant_id (BIGINT, 外部キー)
- raw_number (VARCHAR, 生の番号)
- cleaned_number (VARCHAR, クリーニング後の番号)
- occurrence_count (INT, 出現回数, default: 0)
- first_seen_at (TIMESTAMP)
- last_seen_at (TIMESTAMP)
- resolved (BOOLEAN, default: false)
- resolved_to (VARCHAR, nullable)
- notes (TEXT, nullable)
- timestamps

**インデックス:**
- `[tenant_id, raw_number]` - UNIQUE

### タスク2: UnmappedVehicleNumber モデル作成

`app/models/unmapped_vehicle_number.rb` を作成してください。

**要件:**
- `belongs_to :tenant`
- スコープ: `unresolved` (resolved = false のもの)
- スコープ: `frequent` (occurrence_count > 1 で降順)

### タスク3: VehicleNormalizerサービス作成

`app/services/vehicle_normalizer.rb` を作成してください。

**重要な要件:**
- 初期化: `VehicleNormalizer.new(tenant)`
- メソッド: `normalize(raw_number)` → 正規化された番号を返す
- メソッド: `find_vehicle(raw_number)` → Vehicleオブジェクトを返す

**処理フロー（要件定義書の「4-1. 処理フロー」参照）:**
1. 基本正規化（空白削除、全角→半角）
2. vehiclesテーブルで検索
3. vehicle_aliasesテーブルで検索
4. パターンマッチング
5. 見つからなければUnmappedVehicleNumberに記録

**⚠️ 絶対に守ること:**
- **末尾の英字サフィックス（A, B, C等）は絶対に削除しない**
- 例: "100A番" → "100A" (「番」は削除、「A」は保持)
- 要件定義書の「4-1. 重要な例外ルール」を参照

**パターンマッチングの例:**
```ruby
# ❌ 間違い（これはやらない）
"100A番" → "100" # Aを削除してしまっている

# ✅ 正しい
"100A番" → "100A" # Aを保持
"100番" → "100"
"品川100A" → "100A"
"１００Ａ番" → "100A"
```

### タスク4: テスト作成

`spec/services/vehicle_normalizer_spec.rb` を作成してください。

**テストケース（要件定義書の「6-1. テストケース」参照）:**
- "100" → "100"
- "100番" → "100"
- "品川100" → "100"
- "１００" → "100"
- "100 " → "100"
- **"100A" → "100A"** ← 重要！
- **"100A番" → "100A"** ← 重要！
- **"品川100A" → "100A"** ← 重要！
- **"１００Ａ" → "100A"** ← 重要！

すべてのテストケースを要件定義書から実装してください。

---

## Phase 0-2: 既存インポート処理への統合

### タスク5: インポート処理の修正

`lib/tasks/vehicles.rake` または該当するインポートサービスを修正してください。

**修正箇所:**
```ruby
# 修正前
vehicle_code = row['車番']
vehicle = Vehicle.find_by(registration_number: vehicle_code)

# 修正後
vehicle_code = row['車番']
normalizer = VehicleNormalizer.new(current_tenant)
normalized_code = normalizer.normalize(vehicle_code)
vehicle = normalizer.find_vehicle(vehicle_code)

# ログに記録
if vehicle_code != normalized_code
  Rails.logger.info "Normalized: #{vehicle_code} → #{normalized_code}"
end

if vehicle.nil?
  Rails.logger.warn "Vehicle not found: #{vehicle_code} → #{normalized_code}"
end
```

**元のデータも保存:**
```ruby
# metadata に元の表記を記録
VehicleFinancialMetric.create!(
  tenant: current_tenant,
  vehicle: vehicle,
  vehicle_code: normalized_code,
  # ... その他のフィールド
  metadata: { original_vehicle_code: vehicle_code }
)
```

---

## Phase 0-3: 重複検出機能

### タスク6: DuplicateDetector サービス作成

`app/services/duplicate_detector.rb` を作成してください。

**要件:**
- 既存データ内の重複を検出
- インポートデータと既存データの重複を検出
- 名寄せ後の重複を検出

詳細は要件定義書の「4-4. 重複データ検出」を参照。

**重要:**
```ruby
# ❌ これは重複ではない
"100番" → "100"
"100A番" → "100A"
# 100 と 100A は別の車両

# ✅ これは重複
"100番" → "100"
"品川100" → "100"
# 同じ車両
```

---

## Phase 0-4: 管理画面

### タスク7: VehicleAliases コントローラー作成

`app/controllers/admin/vehicle_aliases_controller.rb` を作成してください。

**アクション:**
- `index` - エイリアス一覧と未マッピング番号一覧
- `create` - エイリアス新規登録
- `bulk_create` - CSV一括登録
- `resolve_unmapped` - 未マッピング番号を解決

### タスク8: ビュー作成

`app/views/admin/vehicle_aliases/index.html.erb` を作成してください。

**表示内容:**
- エイリアス一覧テーブル
- 未マッピング番号一覧テーブル
- 新規登録フォーム
- CSV一括登録フォーム

詳細は要件定義書の「4-5. 管理画面」を参照。

---

## 実装時の注意点

### ⚠️ 絶対に守ること

1. **サフィックス（A, B, C等）は絶対に削除しない**
   - これが最も重要
   - 100 と 100A は別の車両
   
2. **既存のvehicle_aliasesテーブルを活用する**
   - 新しいテーブルは作らない
   - スキーマに既に存在する
   
3. **マルチテナント対応**
   - 必ずtenant_idで絞り込む
   - current_tenantを使う

4. **元のデータも保持**
   - metadataに `original_vehicle_code` を記録
   - 監査・検証のため

### 推奨する実装順序

1. UnmappedVehicleNumberテーブル作成
2. UnmappedVehicleNumberモデル作成
3. VehicleNormalizerサービス作成（サフィックス保持ロジック含む）
4. テスト作成・実行
5. 既存インポート処理への統合
6. 動作確認
7. DuplicateDetectorサービス作成
8. 管理画面作成

### 質問・不明点があれば

要件定義書に記載がない場合や、不明点がある場合は、
実装を進める前に若林さんに確認してください。

特に以下は確認が必要です:
- 新しいパターンが出てきた場合の処理
- エラーハンドリングの方針
- ログの出力レベル

---

## 完了の確認

以下がすべてできたら Phase 0-1, 0-2 完了です:

✅ UnmappedVehicleNumberテーブルが作成されている
✅ VehicleNormalizerが動作する
✅ テストがすべてパスする
✅ 「100A番」→「100A」のテストがパスする（サフィックス保持）
✅ インポート処理で名寄せが動作する
✅ 未マッピング番号が記録される

Phase 0-3 以降は、Phase 0-1, 0-2 が完了してから進めてください。
