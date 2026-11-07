import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Txn.date, order: .reverse) private var txns: [Txn]
    @State private var search = ""
    @State private var filter = 0   // 0 الكل، 1 مصاريف، 2 دخل
    @State private var editing: Txn?
    @State private var showAdd = false

    private var filtered: [Txn] {
        txns.filter { t in
            if filter == 1 && t.isIncome { return false }
            if filter == 2 && !t.isIncome { return false }
            let q = search.trimmingCharacters(in: .whitespaces)
            if q.isEmpty { return true }
            let cat = SpendCategory.of(t.categoryKey).name
            return t.merchant.localizedCaseInsensitiveContains(q)
                || t.note.localizedCaseInsensitiveContains(q)
                || cat.contains(q)
        }
    }

    private var days: [DayGroup] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { DayGroup(day: $0, items: groups[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("عرض", selection: $filter) {
                        Text("الكل").tag(0)
                        Text("مصاريف").tag(1)
                        Text("دخل").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                ForEach(days) { group in
                    Section {
                        ForEach(group.items) { t in
                            Button { editing = t } label: { TxnRow(txn: t) }
                                .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for i in offsets { ctx.delete(group.items[i]) }
                            try? ctx.save()
                        }
                    } header: {
                        let spent = group.items.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
                        HStack {
                            Text(group.day.dayArabic)
                            Spacer()
                            if spent > 0 { Text("صرف \(Money.format(spent))").monospacedDigit() }
                        }
                    }
                }
            }
            .overlay {
                if txns.isEmpty {
                    ContentUnavailableView("ما فيه عمليات", systemImage: "tray",
                                           description: Text("اضغط + عشان تضيف أول عملية، أو الصق رسالة من البنك."))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .searchable(text: $search, prompt: "ابحث باسم المحل أو الفئة")
            .navigationTitle("العمليات")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { t in AddTxnView(editing: t).arabic() }
            .sheet(isPresented: $showAdd) { AddTxnView().arabic() }
        }
    }
}

struct DayGroup: Identifiable {
    let day: Date
    let items: [Txn]
    var id: Date { day }
}
