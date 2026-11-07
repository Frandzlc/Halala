import Foundation
import SwiftData

/// عملية مالية واحدة. المبلغ محفوظ بالهللة (عدد صحيح) عشان الحساب يكون دقيق ١٠٠٪.
@Model
final class Txn {
    var amount: Int
    var isIncome: Bool
    var categoryKey: String
    var merchant: String
    var note: String
    var date: Date
    var rawSMS: String

    init(amount: Int,
         isIncome: Bool,
         categoryKey: String,
         merchant: String = "",
         note: String = "",
         date: Date = .now,
         rawSMS: String = "") {
        self.amount = amount
        self.isIncome = isIncome
        self.categoryKey = categoryKey
        self.merchant = merchant
        self.note = note
        self.date = date
        self.rawSMS = rawSMS
    }
}

/// قاعدة يتعلمها التطبيق: إذا اخترت فئة لمحل معيّن، المرة الجاية يختارها لحاله.
@Model
final class MerchantRule {
    var keyword: String
    var categoryKey: String

    init(keyword: String, categoryKey: String) {
        self.keyword = keyword
        self.categoryKey = categoryKey
    }
}

enum Store {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Txn.self, MerchantRule.self)
        } catch {
            fatalError("تعذر فتح قاعدة البيانات: \(error)")
        }
    }()

    /// يحفظ أو يحدّث قاعدة المحل.
    static func learn(merchant: String, categoryKey: String, in ctx: ModelContext) {
        let key = SMSParser.normalizeMerchant(merchant)
        guard key.count >= 2 else { return }
        let descriptor = FetchDescriptor<MerchantRule>(predicate: #Predicate { $0.keyword == key })
        if let existing = try? ctx.fetch(descriptor).first {
            if existing.categoryKey != categoryKey { existing.categoryKey = categoryKey }
        } else {
            ctx.insert(MerchantRule(keyword: key, categoryKey: categoryKey))
        }
    }

    static func liteRules(in ctx: ModelContext) -> [RuleLite] {
        let rules = (try? ctx.fetch(FetchDescriptor<MerchantRule>())) ?? []
        return rules.map { RuleLite(keyword: $0.keyword, categoryKey: $0.categoryKey) }
    }
}
