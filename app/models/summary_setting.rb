class SummarySetting < ApplicationRecord
  belongs_to :tenant, optional: true

  DEFAULT_TERM_START_MONTH = 9
  DEFAULT_FISCAL_YEAR_ORIGIN = 1950  # 第1期の開始年度（2024年度 = 第75期）
  DEFAULT_LABELS = [
    "輸送収入",
    "車両費計",
    "修繕費計",
    "燃料費計",
    "保険料計",
    "高速代計",
    "人件費計",
    "諸経費計",
    "輸送原価計",
    "営業所損益",
    "本社人件費",
    "本社管理費",
    "損益"
  ].freeze

  def self.for(tenant)
    tenant_id = tenant&.id
    setting = where(tenant_id: tenant_id).first || create_default(tenant_id)
    setting
  end

  def self.create_default(tenant_id)
    create!(
      tenant_id: tenant_id,
      term_start_month: DEFAULT_TERM_START_MONTH,
      fiscal_year_origin: DEFAULT_FISCAL_YEAR_ORIGIN,
      label_mappings: default_mappings
    )
  end

  def self.default_mappings
    mappings = {}
    DEFAULT_LABELS.each { |label| mappings[label] = [label] }
    mappings["輸送収入"] += ["輸送収入計", "輸送収入合計"]
    mappings
  end

  def canonical_labels
    # DEFAULT_LABELSの順序を維持しつつ、追加されたラベルも含める
    ordered = DEFAULT_LABELS & label_mappings.keys
    extra = label_mappings.keys - DEFAULT_LABELS
    ordered + extra
  end

  def aliases_for(label)
    Array(label_mappings[label])
  end
end
