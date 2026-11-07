import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Txn.date, order: .reverse) private var txns: [Txn]
    @State private var showAdd = false
    @State private var showPaste = false
    @State private var editing: Txn?

    private var monthTxns: [Txn] {
        let cal = Calendar.current
        return txns.filter { cal.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }

    private var balance: Int {
        txns.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }

    private var monthIn: Int { monthTxns.filter(\.isIncome).reduce(0) { $0 + $1.amount } }
    private var monthOut: Int { monthTxns.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }

    private var counts: [String: Int] {
        var c: [String: Int] = [:]
        for t in monthTxns where !t.isIncome { c[t.categoryKey, default: 0] += 1 }
        return c
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    balanceCard

                    HStack(spacing: 12) {
                        Button { showAdd = true } label: {
                            Label("أضف عملية", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button { showPaste = true } label: {
                            Label("رسالة بنك", systemImage: "text.bubble")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)

                    let totals = CatTotal.expenses(monthTxns)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("وين صرفت هالشهر")
                            .font(.title3.weight(.bold))
                        if totals.isEmpty {
                            Text("ما فيه مصاريف هالشهر للحين. أضف أول عملية أو الصق رسالة من البنك.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                                ForEach(totals) { ct in
                                    NavigationLink {
                                        CategoryDetailView(category: ct.category)
                                    } label: {
                                        CategoryTile(category: ct.category, amount: ct.amount, count: counts[ct.category.key] ?? 0)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if !txns.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("آخر العمليات")
                                .font(.title3.weight(.bold))
                            VStack(spacing: 14) {
                                ForEach(txns.prefix(8)) { t in
                                    Button { editing = t } label: { TxnRow(txn: t) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("هللة")
            .sheet(isPresented: $showAdd) { AddTxnView().arabic() }
            .sheet(isPresented: $showPaste) { PasteSMSView().arabic() }
            .sheet(item: $editing) { t in AddTxnView(editing: t).arabic() }
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("رصيدك حسب التطبيق")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Money.format(balance))
                    .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("ريال").font(.headline)
            }
            .foregroundStyle(.white)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("دخل الشهر", systemImage: "arrow.down.backward")
                        .font(.caption)
                    Text(Money.format(monthIn)).font(.headline.monospacedDigit())
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Label("صرف الشهر", systemImage: "arrow.up.forward")
                        .font(.caption)
                    Text(Money.format(monthOut)).font(.headline.monospacedDigit())
                }
            }
            .foregroundStyle(.white)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.05, green: 0.45, blue: 0.32), Color(red: 0.1, green: 0.62, blue: 0.42)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

struct CategoryDetailView: View {
    let category: SpendCategory
    @Query(sort: \Txn.date, order: .reverse) private var txns: [Txn]
    @State private var editing: Txn?

    private var items: [Txn] { txns.filter { $0.categoryKey == category.key } }

    var body: some View {
        let monthTotal = items
            .filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
        let allTotal = items.reduce(0) { $0 + $1.amount }

        List {
            Section {
                HStack(spacing: 16) {
                    CategoryIcon(category: category, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name).font(.title2.weight(.bold))
                        Text("هالشهر: \(Money.label(monthTotal))").font(.subheadline)
                        Text("الإجمالي: \(Money.label(allTotal))").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            Section("العمليات") {
                ForEach(items) { t in
                    Button { editing = t } label: { TxnRow(txn: t) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { t in AddTxnView(editing: t).arabic() }
    }
}
