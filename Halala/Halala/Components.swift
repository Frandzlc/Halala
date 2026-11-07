import SwiftUI

struct CategoryIcon: View {
    let category: SpendCategory
    var size: CGFloat = 44
    var filled = false

    var body: some View {
        ZStack {
            Circle().fill(filled ? category.color : category.color.opacity(0.16))
            Image(systemName: category.icon)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(filled ? Color.white : category.color)
        }
        .frame(width: size, height: size)
    }
}

/// بطاقة الفئة: الصورة، وتحتها الاسم، وتحته المبلغ.
struct CategoryTile: View {
    let category: SpendCategory
    let amount: Int
    var count: Int = 0

    var body: some View {
        VStack(spacing: 8) {
            CategoryIcon(category: category, size: 58)
            Text(category.name)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(Money.format(amount))
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
            Text(count == 1 ? "عملية وحدة" : "\(count) عمليات")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}

struct TxnRow: View {
    let txn: Txn

    var body: some View {
        let cat = SpendCategory.of(txn.categoryKey)
        HStack(spacing: 12) {
            CategoryIcon(category: cat)
            VStack(alignment: .leading, spacing: 3) {
                Text(txn.merchant.isEmpty ? cat.name : txn.merchant)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("\(cat.name) · \(txn.date.shortArabic)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text((txn.isIncome ? "+" : "−") + Money.format(txn.amount))
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(txn.isIncome ? Color.green : Color.primary)
        }
        .contentShape(Rectangle())
    }
}

struct StatColumn: View {
    let title: String
    let amount: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(Money.format(amount))
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}
