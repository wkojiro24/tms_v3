class ProfitLossService
  STANDARD_PL_STRUCTURE = [
    { code: "sales", name: "売上高", type: :section, children: [] },
    { code: "cost_of_sales", name: "売上原価", type: :section, children: [] },
    { code: "gross_profit", name: "売上総利益", type: :calculated, expression: "sales - cost_of_sales" },
    { code: "sga_expenses", name: "販売費及び一般管理費", type: :section, children: [] },
    { code: "operating_income", name: "営業利益", type: :calculated, expression: "gross_profit - sga_expenses" },
    { code: "non_operating_income", name: "営業外収益", type: :section, children: [] },
    { code: "non_operating_expenses", name: "営業外費用", type: :section, children: [] },
    { code: "ordinary_income", name: "経常利益", type: :calculated, expression: "operating_income + non_operating_income - non_operating_expenses" },
    { code: "extraordinary_gains", name: "特別利益", type: :section, children: [] },
    { code: "extraordinary_losses", name: "特別損失", type: :section, children: [] },
    { code: "income_before_tax", name: "税引前当期純利益", type: :calculated, expression: "ordinary_income + extraordinary_gains - extraordinary_losses" },
    { code: "income_taxes", name: "法人税等", type: :section, children: [] },
    { code: "net_income", name: "当期純利益", type: :calculated, expression: "income_before_tax - income_taxes" }
  ].freeze

  # 消費税率（税込→税抜変換用）
  TAX_RATE = 0.10

  attr_reader :tenant, :period_start, :period_end, :tax_included

  def initialize(tenant:, period_start:, period_end:, tax_included: true)
    @tenant = tenant
    @period_start = period_start
    @period_end = period_end
    @tax_included = tax_included  # true: 入力データが税込、結果は税抜で出力
  end

  def generate
    journal_totals = fetch_journal_totals
    tree_nodes = fetch_tree_nodes
    mappings = fetch_mappings

    result = build_pl_structure(tree_nodes, mappings, journal_totals)
    calculate_derived_values(result)

    result
  end

  def generate_monthly
    months = []
    current = fiscal_year_start
    while current <= period_end
      month_end = current.end_of_month
      months << {
        year: current.year,
        month: current.month,
        label: current.strftime("%Y/%m"),
        data: ProfitLossService.new(
          tenant: tenant,
          period_start: current,
          period_end: month_end
        ).generate
      }
      current = current.next_month
    end
    months
  end

  private

  def fiscal_year_start
    start_month = summary_setting.term_start_month
    if period_start.month >= start_month
      Date.new(period_start.year, start_month, 1)
    else
      Date.new(period_start.year - 1, start_month, 1)
    end
  end

  def summary_setting
    @summary_setting ||= SummarySetting.for(tenant)
  end

  def fetch_journal_totals
    ActsAsTenant.with_tenant(tenant) do
      if tax_included
        # 税込データの場合、税抜金額を計算（金額 - 消費税額）
        # tax_amountがnilの場合は0として扱う
        JournalLine.joins(:journal_entry)
                   .where(journal_entries: { entry_date: period_start..period_end })
                   .group(:account_name, :side)
                   .sum('amount - COALESCE(tax_amount, 0)')
      else
        JournalLine.joins(:journal_entry)
                   .where(journal_entries: { entry_date: period_start..period_end })
                   .group(:account_name, :side)
                   .sum(:amount)
      end
    end
  end

  def fetch_tree_nodes
    ActsAsTenant.with_tenant(tenant) do
      PlTreeNode.includes(:children).order(:display_order).to_a
    end
  end

  def fetch_mappings
    ActsAsTenant.with_tenant(tenant) do
      PlMapping.active.includes(:pl_tree_node).order(:priority).to_a
    end
  end

  def build_pl_structure(tree_nodes, mappings, journal_totals)
    root_nodes = tree_nodes.select { |n| n.parent_id.nil? }

    result = {
      sections: [],
      totals: {},
      unmapped_accounts: []
    }

    mapped_accounts = Set.new

    root_nodes.each do |root|
      section = build_section(root, tree_nodes, mappings, journal_totals, mapped_accounts, parent_is_expense: false)
      result[:sections] << section
      result[:totals][root.code] = section[:total]
    end

    result[:unmapped_accounts] = find_unmapped_accounts(journal_totals, mapped_accounts)

    result
  end

  def build_section(node, all_nodes, mappings, journal_totals, mapped_accounts, parent_is_expense: false)
    children = all_nodes.select { |n| n.parent_id == node.id }
    node_mappings = mappings.select { |m| m.pl_tree_node_id == node.id }

    # このノードが費用セクションかどうか
    is_expense = expense_section?(node) || parent_is_expense

    amount = calculate_node_amount(node_mappings, journal_totals, mapped_accounts, invert_revenue: is_expense)

    child_sections = children.map do |child|
      build_section(child, all_nodes, mappings, journal_totals, mapped_accounts, parent_is_expense: is_expense)
    end

    total = amount + child_sections.sum { |c| c[:total] }

    {
      code: node.code,
      name: node.name,
      node_type: node.node_type,
      expression: node.expression,
      amount: amount,
      children: child_sections,
      total: total,
      depth: node.depth
    }
  end

  def expense_section?(node)
    %w[cost_of_sales sga_expenses non_operating_expenses extraordinary_losses income_taxes].include?(node.code)
  end

  def calculate_node_amount(mappings, journal_totals, mapped_accounts, invert_revenue: false)
    total = 0

    mappings.each do |mapping|
      journal_totals.each do |(account_name, side), amount|
        if matches_mapping?(mapping, account_name)
          mapped_accounts << account_name
          if revenue_account?(mapping, account_name)
            # 収益勘定: 貸方がプラス
            line_amount = (side == "credit" ? amount : -amount)
            # 費用セクション内の収益は控除（マイナス）にする
            total += invert_revenue ? -line_amount : line_amount
          else
            # 費用勘定: 借方がプラス
            total += (side == "debit" ? amount : -amount)
          end
        end
      end
    end

    total
  end

  def matches_mapping?(mapping, account_name)
    if mapping.account_name.present?
      # [製]などのプレフィックスがあるマッピングは完全一致
      # そうでなければ、完全一致または末尾一致（[製]給料手当 と 給料手当 を区別）
      if mapping.account_name.start_with?("[")
        return true if account_name == mapping.account_name
      else
        # 完全一致、または勘定科目名がマッピング名で終わる場合（ただし先頭に何かある場合は除外）
        return true if account_name == mapping.account_name
      end
    end
    return true if mapping.account_code.present? && account_name == mapping.account_code
    false
  end

  def revenue_account?(mapping, account_name)
    node = mapping.pl_tree_node
    return true if node&.code&.include?("sales")
    return true if node&.code&.include?("revenue")
    return true if node&.code&.include?("income")
    return true if node&.code&.include?("gain")  # 売却益など

    # 親ノードが営業外収益または特別利益の場合も収益として扱う
    if node&.parent_id
      parent = PlTreeNode.find_by(id: node.parent_id)
      return true if parent&.code == "non_operating_income"
      return true if parent&.code == "extraordinary_gains"
    end

    account_name.include?("売上") ||
      account_name.include?("収益") ||
      account_name.include?("収入") ||
      account_name.include?("還元金") ||
      account_name.include?("負担金") ||
      account_name.include?("売却益")
  end

  def calculate_derived_values(result)
    totals = result[:totals]

    totals["gross_profit"] = (totals["sales"] || 0) - (totals["cost_of_sales"] || 0)
    # 販管費は sga_expenses + branch_admin + hq_cost の合計
    total_sga = (totals["sga_expenses"] || 0) + (totals["branch_admin"] || 0) + (totals["hq_cost"] || 0)
    totals["operating_income"] = (totals["gross_profit"] || 0) - total_sga
    totals["ordinary_income"] = (totals["operating_income"] || 0) +
                                 (totals["non_operating_income"] || 0) -
                                 (totals["non_operating_expenses"] || 0)
    totals["income_before_tax"] = (totals["ordinary_income"] || 0) +
                                   (totals["extraordinary_gains"] || 0) -
                                   (totals["extraordinary_losses"] || 0)
    totals["net_income"] = (totals["income_before_tax"] || 0) - (totals["income_taxes"] || 0)

    derived_sections = [
      { code: "gross_profit", name: "売上総利益" },
      { code: "operating_income", name: "営業利益" },
      { code: "ordinary_income", name: "経常利益" },
      { code: "income_before_tax", name: "税引前当期純利益" },
      { code: "net_income", name: "当期純利益" }
    ]

    derived_sections.each do |ds|
      unless result[:sections].any? { |s| s[:code] == ds[:code] }
        result[:sections] << {
          code: ds[:code],
          name: ds[:name],
          node_type: "calculated",
          amount: totals[ds[:code]] || 0,
          total: totals[ds[:code]] || 0,
          children: [],
          depth: 0
        }
      end
    end
  end

  def find_unmapped_accounts(journal_totals, mapped_accounts)
    unmapped = []

    journal_totals.each do |(account_name, side), amount|
      next if mapped_accounts.include?(account_name)

      existing = unmapped.find { |u| u[:account_name] == account_name }
      if existing
        if side == "debit"
          existing[:debit] += amount
        else
          existing[:credit] += amount
        end
      else
        unmapped << {
          account_name: account_name,
          debit: side == "debit" ? amount : 0,
          credit: side == "credit" ? amount : 0
        }
      end
    end

    unmapped.sort_by { |u| -(u[:debit] + u[:credit]).abs }
  end
end
