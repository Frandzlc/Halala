import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \MerchantRule.keyword) private var rules: [MerchantRule]
    @Query(sort: \Txn.date, order: .reverse) private var txns: [Txn]
    @State private var exportURL: URL?
    @State private var confirmWipe = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("خلّ كل رسالة بنك تنسجل لحالها", systemImage: "bolt.fill")
                            .font(.headline)
                        Text("""
                        ١. افتح تطبيق «الاختصارات» ← «الأتمتة» ← زر +.
                        ٢. اختر «رسالة» ← «الرسالة تحتوي على» واكتب: SAR (أو: مبلغ).
                        ٣. اختر «تشغيل فورًا» ثم «التالي».
                        ٤. «أتمتة فارغة جديدة» ← أضف إجراء ← ابحث عن «هللة» ← «سجّل رسالة بنك».
                        ٥. اضغط على «نص الرسالة» واختر «مدخلات الاختصار» ← «المحتوى».
                        خلاص! أي رسالة شراء أو حوالة تجيك تنضاف هنا مباشرة.
                        """)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("التسجيل التلقائي")
                }

                Section {
                    if rules.isEmpty {
                        Text("لما تختار فئة لمحل، التطبيق يحفظها ويستخدمها المرة الجاية.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(rules) { r in
                        let cat = SpendCategory.of(r.categoryKey)
                        HStack(spacing: 12) {
                            CategoryIcon(category: cat, size: 32)
                            Text(r.keyword).lineLimit(1)
                            Spacer()
                            Text(cat.name).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { ctx.delete(rules[i]) }
                        try? ctx.save()
                    }
                } header: {
                    Text("المحلات اللي تعلّمها التطبيق")
                }

                Section("بياناتك") {
                    if let url = exportURL {
                        ShareLink(item: url) {
                            Label("شارك ملف العمليات (CSV)", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            exportURL = makeCSV()
                        } label: {
                            Label("تصدير العمليات لملف Excel", systemImage: "tablecells")
                        }
                        .disabled(txns.isEmpty)
                    }
                    Button(role: .destructive) {
                        confirmWipe = true
                    } label: {
                        Label("مسح كل البيانات", systemImage: "trash")
                    }
                }

                Section {
                    HStack {
                        Text("هللة")
                        Spacer()
                        Text("نسخة 1.0 · \(txns.count) عملية").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("كل بياناتك محفوظة على جوالك فقط، وما تطلع لأي مكان.")
                }
            }
            .navigationTitle("الإعدادات")
            .confirmationDialog("بتنمسح كل العمليات والمحلات المحفوظة. متأكد؟", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("امسح كل شي", role: .destructive) { wipe() }
            }
            .onChange(of: txns.count) { _, _ in exportURL = nil }
        }
    }

    private func makeCSV() -> URL? {
        func esc(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm"
        var csv = "\u{FEFF}التاريخ,النوع,الفئة,المحل,المبلغ (ريال),ملاحظة\n"
        for t in txns {
            let row = [
                df.string(from: t.date),
                t.isIncome ? "دخل" : "مصروف",
                SpendCategory.of(t.categoryKey).name,
                t.merchant,
                (t.isIncome ? "" : "-") + Money.plain(t.amount),
                t.note,
            ].map(esc).joined(separator: ",")
            csv += row + "\n"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("halala-transactions.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func wipe() {
        for t in txns { ctx.delete(t) }
        for r in rules { ctx.delete(r) }
        try? ctx.save()
        exportURL = nil
    }
}
