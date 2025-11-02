# Journal Drilldown Notes

## Data Model Overview
- `import_batches`: Excel インポートの実行単位。元ファイル名・読み込み日時・期間などを記録。
- `journal_entries`: 伝票ヘッダ。日付・伝票番号・摘要・出典シート・元行番号レンジ・メタ情報を保持。
- `journal_lines`: 伝票明細。`side`（debit/credit）、勘定科目、補助科目、部門、金額、税区分、原本行番号等を持ち、1 伝票に対して複数行ぶら下がる。
- 既存の PL 系テーブル（`pl_tree_nodes` / `pl_mappings` / `snapshots` など）はそのまま残しておき、将来必要になった際に `journal_lines` ベースで再計算できるようにする。

## Import Pipeline (Excel → JournalEntry / JournalLine)
1. `Imports::JournalImporter` が 2 段ヘッダ（3行目・4行目）を解析し、シート毎にループ。伝票番号・日付・摘要をキーに `JournalEntry` をキャッシュしながら進める。
2. 各 Excel 行から、借方側に値があれば `side: :debit` の `JournalLine` を生成。貸方側に値があれば `side: :credit` の `JournalLine` を生成。税区分や補助科目などは side 別にラインメタデータへ格納。
3. 伝票ごとに元シート名・開始/終了行番号・メモ（摘要等）を `journal_entries.metadata` に蓄積し、最後にまとめて保存。これで Excel の構造を崩さずに Web UI で展開できる。

## 明細ビューの方針
1. 伝票一覧テーブル：日付・伝票No・摘要・行数などを表示。クリックで明細行を展開。
2. 展開時は借方／貸方を色分けし、勘定科目・補助科目・部門・金額・税込区分・原本シート/行番号を表示。
3. フィルタ: 期間（YYYY-MM）、勘定科目、部門、相手先、フリーワードなど。検索結果は CSV エクスポート可能にする予定。

## 今後の ToDo
- importer の単体テスト用フィクスチャを整備し、借方・貸方が複数行に分かれるケースや金額一致チェックを自動化。
- 伝票一覧 API / Controller / View のスケルトン作成（Turbo Frame or JSON + front-end）。
- 例外チェック（借方と貸方の合計差異）やタグ付けは必要になった時点で追加。
- 旧 `journals` ベースで作っていた分類・車両推定・PL スナップショットは未対応。必要になったら `journal_lines` に合わせて再設計する。
