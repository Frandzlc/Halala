import SwiftUI
import SwiftData

struct TxnDraft {
    var isIncome = false
    var amountText = ""
    var categoryKey = "other_exp"
    var merchant = ""
    var note = ""
    var date = Date.now
    var rawSMS = ""
}

struct AddTxnView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TxnDraft
    @State private var pickedManually: Bool
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool
    private let editing: Txn?

    init(draft: TxnDraft = TxnDraft(), categoryAlreadyGuessed: Bool = false) {
        _draft = State(initialValue: draft)
        _pickedManually = State(initialValue: categoryAlreadyGuessed)
        editing = nil
    }

    init(editing t: Txn) {
        _draft = State(initialValue: TxnDraft(isIncome: t.isIncome,
                                              amountText: Money.plain(t.amount),
                                              categoryKey: t.categoryKey,
                                              merchant: t.merchant,
                                              note: t.note,
                                              date: t.date,
                                              rawSMS: t.rawSMS))
        _pickedManually = State(initialValue: true)
        editing = t
    }

    private var amount: Int? { Money.parseHalalas(draft.amountText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("النوع", selection: $draft.isIncome) {
                        Text("مصروف").tag(false)
                        Text("دخل / حوالة").tag(true)
                    }
                    .pickerStyle(.segmented)

                    HStack(alignment: .firstTextBaseline) {
                        TextField("0.00", text: $draft.amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .focused($amountFocused)
                        Text("ريال").font(.title3).foregroundStyle(.secondary)
                    }
                } footer: {
                    if let a = amount, a > 0 {
                        Text("= \(a) هللة")
                    }
                }

                Section("الفئة") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
                        ForEach(SpendCategory.list(income: draft.isIncome)) { c in
                            let selected = c.key == draft.categoryKey
                            Button {
                                draft.categoryKey = c.key
                                pickedManually = true
                            } label: {
                                VStack(spacing: 6) {
                                    CategoryIcon(category: c, size: 50, filled: selected)
                                    Text(c.name)
                                        .font(.caption2.weight(selected ? .bold : .regular))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("التفاصيل") {
                    TextField(draft.isIncome ? "من مين؟" : "وين صرفت؟ (اسم المحل)", text: $draft.merchant)
                    TextField("ملاحظة (اختياري)", text: $draft.note)
                    DatePicker("التاريخ", selection: $draft.date)
                }

                if !draft.rawSMS.isEmpty {
                    Section("نص رسالة البنك") {
                        Text(draft.rawSMS)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if editing != nil {
                    Section {
                        Button("حذف العملية", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(editing == nil ? "عملية جديدة" : "تعديل العملية")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }
                        .fontWeight(.bold)
                        .disabled((amount ?? 0) <= 0)
                }
            }
            .onChange(of: draft.isIncome) { _, newValue in
                if SpendCategory.of(draft.categoryKey).isIncome != newValue {
                    draft.categoryKey = newValue ? "transfer_in" : "other_exp"
                    pickedManually = false
                }
            }
            .onChange(of: draft.merchant) { _, newValue in
                guard !pickedManually else { return }
                let guess = SMSParser.guessCategory(merchant: newValue,
                                                    fullText: newValue,
                                                    isIncome: draft.isIncome,
                                                    rules: Store.liteRules(in: ctx))
                draft.categoryKey = guess
            }
            .confirmationDialog("متأكد تبي تحذف العملية؟", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("حذف", role: .destructive) {
                    if let e = editing { ctx.delete(e) }
                    try? ctx.save()
                    dismiss()
                }
            }
            .onAppear {
                if editing == nil && draft.amountText.isEmpty { amountFocused = true }
            }
        }
    }

    private func save() {
        guard let a = amount, a > 0 else { return }
        let merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let e = editing {
            e.amount = a
            e.isIncome = draft.isIncome
            e.categoryKey = draft.categoryKey
            e.merchant = merchant
            e.note = note
            e.date = draft.date
        } else {
            ctx.insert(Txn(amount: a,
                           isIncome: draft.isIncome,
                           categoryKey: draft.categoryKey,
                           merchant: merchant,
                           note: note,
                           date: draft.date,
                           rawSMS: draft.rawSMS))
        }
        if !merchant.isEmpty && draft.categoryKey != "other_exp" && draft.categoryKey != "other_inc" {
            Store.learn(merchant: merchant, categoryKey: draft.categoryKey, in: ctx)
        }
        try? ctx.save()
        dismiss()
    }
}
