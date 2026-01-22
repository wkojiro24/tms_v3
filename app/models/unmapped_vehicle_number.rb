# 名寄せできなかった車両番号を記録するモデル
class UnmappedVehicleNumber < ApplicationRecord
  acts_as_tenant :tenant

  # --- Validations ---
  validates :raw_number, presence: true, uniqueness: { scope: :tenant_id }
  validates :first_seen_at, presence: true
  validates :last_seen_at, presence: true

  # --- Scopes ---
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved_records, -> { where(resolved: true) }
  scope :frequent, -> { where("occurrence_count > 1").order(occurrence_count: :desc) }
  scope :recent, -> { order(last_seen_at: :desc) }

  # --- Class Methods ---

  # 未マッピング番号を記録または更新
  # @param raw_number [String] 生の車両番号
  # @param cleaned_number [String] クリーニング後の番号
  # @return [UnmappedVehicleNumber]
  def self.record_unmapped(raw_number, cleaned_number = nil)
    record = find_or_initialize_by(raw_number: raw_number)

    if record.new_record?
      record.cleaned_number = cleaned_number
      record.first_seen_at = Time.current
      record.last_seen_at = Time.current
      record.occurrence_count = 1
    else
      record.last_seen_at = Time.current
      record.occurrence_count += 1
    end

    record.save!
    record
  end

  # --- Instance Methods ---

  # この番号を解決済みにする
  # @param resolved_to [String] 解決先の正規番号
  # @param notes [String] メモ
  def resolve!(resolved_to:, notes: nil)
    update!(
      resolved: true,
      resolved_to: resolved_to,
      notes: notes
    )
  end

  # 解決を取り消す
  def unresolve!
    update!(
      resolved: false,
      resolved_to: nil
    )
  end
end
