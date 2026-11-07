import SwiftUI

struct SpendCategory: Identifiable, Hashable {
    let key: String
    let name: String
    let icon: String
    let color: Color
    let isIncome: Bool

    var id: String { key }

    static let expense: [SpendCategory] = [
        .init(key: "coffee", name: "قهوة", icon: "cup.and.saucer.fill", color: .brown, isIncome: false),
        .init(key: "food", name: "مطاعم", icon: "fork.knife", color: .orange, isIncome: false),
        .init(key: "grocery", name: "بقالة", icon: "cart.fill", color: .green, isIncome: false),
        .init(key: "fuel", name: "بنزين", icon: "fuelpump.fill", color: .red, isIncome: false),
        .init(key: "transport", name: "مواصلات", icon: "car.fill", color: .blue, isIncome: false),
        .init(key: "shopping", name: "تسوق", icon: "bag.fill", color: .pink, isIncome: false),
        .init(key: "bills", name: "فواتير", icon: "doc.text.fill", color: .indigo, isIncome: false),
        .init(key: "telecom", name: "اتصالات", icon: "antenna.radiowaves.left.and.right", color: .teal, isIncome: false),
        .init(key: "health", name: "صحة", icon: "cross.case.fill", color: .mint, isIncome: false),
        .init(key: "entertainment", name: "ترفيه", icon: "gamecontroller.fill", color: .purple, isIncome: false),
        .init(key: "travel", name: "سفر", icon: "airplane", color: .cyan, isIncome: false),
        .init(key: "education", name: "تعليم", icon: "book.fill", color: .yellow, isIncome: false),
        .init(key: "rent", name: "سكن", icon: "house.fill", color: Color(red: 0.55, green: 0.45, blue: 0.35), isIncome: false),
        .init(key: "gifts", name: "هدايا", icon: "gift.fill", color: Color(red: 0.85, green: 0.3, blue: 0.5), isIncome: false),
        .init(key: "cash", name: "سحب نقدي", icon: "wallet.pass.fill", color: Color(red: 0.3, green: 0.5, blue: 0.3), isIncome: false),
        .init(key: "transfer_out", name: "حوالة صادرة", icon: "arrow.up.forward.circle.fill", color: .gray, isIncome: false),
        .init(key: "other_exp", name: "أخرى", icon: "ellipsis.circle.fill", color: .secondary, isIncome: false),
    ]

    static let income: [SpendCategory] = [
        .init(key: "salary", name: "راتب", icon: "banknote.fill", color: .green, isIncome: true),
        .init(key: "transfer_in", name: "حوالة واردة", icon: "arrow.down.backward.circle.fill", color: .teal, isIncome: true),
        .init(key: "refund", name: "استرداد", icon: "arrow.uturn.backward.circle.fill", color: .blue, isIncome: true),
        .init(key: "other_inc", name: "دخل آخر", icon: "plus.circle.fill", color: .mint, isIncome: true),
    ]

    static let all: [SpendCategory] = expense + income

    static func of(_ key: String) -> SpendCategory {
        all.first { $0.key == key } ?? expense[expense.count - 1]
    }

    static func list(income: Bool) -> [SpendCategory] {
        income ? Self.income : Self.expense
    }
}

struct CatTotal: Identifiable {
    let category: SpendCategory
    let amount: Int
    var id: String { category.key }

    static func expenses(_ txns: [Txn]) -> [CatTotal] {
        var sums: [String: Int] = [:]
        for t in txns where !t.isIncome { sums[t.categoryKey, default: 0] += t.amount }
        return sums
            .map { CatTotal(category: SpendCategory.of($0.key), amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}

enum AppLocale {
    static let locale = Locale(identifier: "ar_SA@calendar=gregorian;numbers=latn")
}

extension View {
    /// يخلي الواجهة عربية من اليمين لليسار بتقويم ميلادي.
    func arabic() -> some View {
        self
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, AppLocale.locale)
    }
}

extension Date {
    var shortArabic: String {
        formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(AppLocale.locale))
    }
    var dayArabic: String {
        formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.locale))
    }
    var monthArabic: String {
        formatted(.dateTime.month(.wide).year().locale(AppLocale.locale))
    }
}
