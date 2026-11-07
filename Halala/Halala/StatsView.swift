import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Txn.date, order: .reverse) private var txns: [Txn]
    @State private var monthOffset = 0

    private var monthStart: Date {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return cal.date(byAdding: .month, value: monthOffset, to: start) ?? start
    }

    private var monthTxns: [Txn] {
        let cal = Calendar.current
        let m = monthStart
        return txns.filter { cal.isDate($0.date, equalTo: m, toGranularity: .month) }
    }

    var body: some View {
        let items = monthTxns
        let income = items.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let spent = items.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let totals = CatTotal.expenses(items)

        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { monthOffset -= 1 } label: {
                            Image(systemName: "chevron.backward").padding(8)
                        }
                        Spacer()
                        Text(monthStart.monthArabic).font(.headline)
                        Spacer()
                        Button { monthOffset += 1 } label: {
                            Image(systemName: "chevron.forward").padding(8)
                        }
                        .disabled(monthOffset >= 0)
                    }
                    .buttonStyle(.borderless)

                    HStack {
                        StatColumn(title: "الدخل", amount: income, color: .green)
                        Divider()
                        StatColumn(title: "المصروف", amount: spent, color: .red)
                        Divider()
                        StatColumn(title: "الصافي", amount: income - spent, color: income - spent >= 0 ? .primary : .red)
                    }
                    .padding(.vertical, 6)
                }

                Section("وين راحت فلوسك") {
                    if totals.isEmpty {
                        Text("ما فيه مصاريف في هالشهر.")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(totals) { ct in
                            SectorMark(angle: .value("المبلغ", ct.amount),
                                       innerRadius: .ratio(0.62),
                                       angularInset: 1.5)
                                .cornerRadius(4)
                                .foregroundStyle(ct.category.color)
                        }
                        .frame(height: 230)
                        .overlay {
                            VStack(spacing: 2) {
                                Text("المجموع").font(.caption).foregroundStyle(.secondary)
                                Text(Money.format(spent)).font(.title3.weight(.bold).monospacedDigit())
                                Text("ريال").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)

                        ForEach(totals) { ct in
                            HStack(spacing: 12) {
                                CategoryIcon(category: ct.category, size: 38)
                                Text(ct.category.name).font(.body.weight(.semibold))
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Money.format(ct.amount)).font(.callout.weight(.bold).monospacedDigit())
                                    Text(percent(ct.amount, of: spent)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                let incomeTotals = incomeByCategory(items)
                if !incomeTotals.isEmpty {
                    Section("مصادر الدخل") {
                        ForEach(incomeTotals) { ct in
                            HStack(spacing: 12) {
                                CategoryIcon(category: ct.category, size: 38)
                                Text(ct.category.name)
                                Spacer()
                                Text("+" + Money.format(ct.amount))
                                    .font(.callout.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("الإحصائيات")
        }
    }

    private func percent(_ part: Int, of total: Int) -> String {
        guard total > 0 else { return "" }
        let p = Double(part) / Double(total) * 100
        return String(format: "%.0f%%", p)
    }

    private func incomeByCategory(_ items: [Txn]) -> [CatTotal] {
        var sums: [String: Int] = [:]
        for t in items where t.isIncome { sums[t.categoryKey, default: 0] += t.amount }
        return sums.map { CatTotal(category: SpendCategory.of($0.key), amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}
