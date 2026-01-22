# TMS Portal

社内ポータル（ダッシュボード、給与管理、承認ワークフローなど）をまとめた Ruby on Rails アプリケーションです。

## 主な機能

- **ダッシュボード**：日常業務向けのメニューと KPI モジュール。
- **給与インポート／グリッド表示**：Excel レイアウトを再現する給与ビューと履歴閲覧。
- **承認ワークフロー**：
  - カテゴリ単位で承認ステップを定義（車両修理・備品購入など）。
  - 申請者はカテゴリ、金額、添付資料（相見積もり等）を登録。
  - 承認者はブラウザ上で添付プレビュー（PDF / 画像）を確認しながら承認・保留・差戻し・却下を実行。
  - 最終承認が完了すると関係ロールへ通知（現状はログ出力、後からメール等に差し替え可能）。
- **管理者機能**：ユーザー追加・編集、承認カテゴリ／ステージ設定、申請の承認処理。

## 開発環境

- Ruby 3.3.4
- Rails 7.x
- PostgreSQL
- Node.js 18 以上
- npm または Yarn

## セットアップ

```sh
# 依存ライブラリ
bundle install
npm install

# データベース作成 & マイグレーション
bin/rails db:create
bin/rails db:migrate

# 初期データ（管理者・スタッフ・承認カテゴリ・サンプルユーザーなど）
bin/rails db:seed

# 開発サーバ
bin/rails server
```

起動後 `http://localhost:3000` にアクセスしてください。

- 管理者: `admin@example.com` / `password`
- スタッフ（申請者例）: `staff@example.com` / `password`
- 追加で `approver@example.com`, `manager@example.com`, `maintenance@example.com`, `purchasing@example.com`, `accounting@example.com` も `password` で利用できます。

## ワークフローの使い方

1. 左メニュー「ワークフロー」から申請一覧を開き、新規申請を作成します。
2. カテゴリを選択すると定義済みの承認ステップがコピーされます。
3. 金額や取引先、必要日、相見積りなどの添付資料を入力・アップロードし申請。
4. 担当承認者は「承認タスク」画面で内容と添付をプレビューし、承認／保留／差戻し／却下を実行します。
5. 最終承認後は通知ロールに応じたログが出力され、経理など関係部署に共有できます（将来的にメール等へ拡張可能）。

## テスト

RSpec を導入しています。

```sh
bin/rails db:test:prepare
bundle exec rspec
```

## 車両データ管理

- `data/journals/車両台帳一覧表.csv` … 車両一覧のシードデータ（`bin/rails db:seed` 内で取り込み）。
- `data/vehicle_financials/<期>/<原価計算YYMM>.xls[x|m]` … 月次の車両別収支 Excel。旧形式の `.xls` ファイルを読むために `roo-xls` を追加しているので、`bundle install` を忘れずに実行してください。

月次収支を読み込みたい場合は、以下の Rake タスクを実行してください。

```sh
bin/rails "vehicles:import_financials[data/vehicle_financials/原価計算2508.xlsm]"

# ディレクトリ配下の全 Excel を一括で取り込む場合
bin/rails "vehicles:import_financials_batch[data/vehicle_financials]"
```

同月・同ファイル名の既存データは削除された上で再取り込みされます。除外したい車番（9999, 8888 など）はサービス側で設定できます。
