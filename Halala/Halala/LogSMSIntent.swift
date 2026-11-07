import AppIntents
import SwiftData

/// إجراء في تطبيق «الاختصارات»: يستقبل نص رسالة البنك ويسجّل العملية مباشرة.
struct LogBankSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "سجّل رسالة بنك"
    static var description = IntentDescription("يقرأ رسالة البنك (شراء أو حوالة) ويسجّلها في هللة تلقائيًا.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "نص الرسالة")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ctx = Store.container.mainContext
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // ما نسجل نفس الرسالة مرتين
        let dup = FetchDescriptor<Txn>(predicate: #Predicate { $0.rawSMS == raw })
        if let existing = try? ctx.fetch(dup), !existing.isEmpty {
            return .result(dialog: "هالرسالة مسجلة من قبل.")
        }

        guard let p = SMSParser.parse(raw, rules: Store.liteRules(in: ctx)) else {
            return .result(dialog: "ما لقيت مبلغ في الرسالة، ما سجلت شي.")
        }

        ctx.insert(Txn(amount: p.amount,
                       isIncome: p.isIncome,
                       categoryKey: p.categoryKey,
                       merchant: p.merchant,
                       date: .now,
                       rawSMS: raw))
        try ctx.save()

        let cat = SpendCategory.of(p.categoryKey).name
        let sign = p.isIncome ? "+" : "−"
        let place = p.merchant.isEmpty ? cat : "\(cat) · \(p.merchant)"
        let message = "تم: \(sign)\(Money.label(p.amount)) — \(place)"
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct HalalaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogBankSMSIntent(),
            phrases: [
                "سجل رسالة بنك في \(.applicationName)",
                "\(.applicationName) سجل رسالة",
            ],
            shortTitle: "سجّل رسالة بنك",
            systemImageName: "text.bubble.fill"
        )
    }
}
