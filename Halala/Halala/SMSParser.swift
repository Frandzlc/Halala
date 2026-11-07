import Foundation

// MARK: - المبالغ (هللة / ريال)

enum Money {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// 1250 → "12.50"
    static func format(_ halalas: Int) -> String {
        let sign = halalas < 0 ? "-" : ""
        let value = Decimal(abs(halalas)) / 100
        let text = formatter.string(from: value as NSDecimalNumber) ?? "0.00"
        return sign + text
    }

    /// 1250 → "12.50 ريال"
    static func label(_ halalas: Int) -> String { "\(format(halalas)) ريال" }

    /// للتعديل داخل حقل الإدخال: 1250 → "12.50"
    static func plain(_ halalas: Int) -> String {
        let a = abs(halalas)
        return "\(a / 100).\(String(format: "%02d", a % 100))"
    }

    /// يحوّل الأرقام العربية/الفارسية إلى أرقام إنجليزية.
    static func normalizeDigits(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "٠", "۰": out.append("0")
            case "١", "۱": out.append("1")
            case "٢", "۲": out.append("2")
            case "٣", "۳": out.append("3")
            case "٤", "۴": out.append("4")
            case "٥", "۵": out.append("5")
            case "٦", "۶": out.append("6")
            case "٧", "۷": out.append("7")
            case "٨", "۸": out.append("8")
            case "٩", "۹": out.append("9")
            case "٫": out.append(".")
            case "٬": out.append(",")
            default: out.append(ch)
            }
        }
        return out
    }

    /// "12.5" → 1250 ، "1,200" → 120000 ، "٣٥" → 3500
    static func parseHalalas(_ input: String) -> Int? {
        let t = normalizeDigits(input)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let parts = t.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let wholeText = parts[0].isEmpty ? "0" : String(parts[0])
        guard wholeText.allSatisfy({ $0.isASCII && $0.isNumber }),
              let whole = Int(wholeText) else { return nil }
        var frac = 0
        if parts.count == 2 {
            var f = String(parts[1].prefix(2))
            guard f.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            if f.count == 1 { f += "0" }
            if f.isEmpty { f = "00" }
            frac = Int(f) ?? 0
        }
        guard whole < 100_000_000 else { return nil }
        return whole * 100 + frac
    }
}

// MARK: - قراءة رسائل البنك

struct RuleLite {
    let keyword: String
    let categoryKey: String
}

struct ParsedSMS {
    var amount: Int
    var isIncome: Bool
    var categoryKey: String
    var merchant: String
}

enum SMSParser {
    static let incomeCategoryKeys: Set<String> = ["salary", "transfer_in", "refund", "other_inc"]

    private static let number = #"([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)"#
    private static let currency = #"(?:SAR|SR|ر\.\s?س|ريال|﷼)"#

    private static var amountPatterns: [String] {
        [
            currency + #"\s*[:.]?\s*"# + number,
            number + #"\s*"# + currency,
            #"(?:مبلغ|المبلغ|بمبلغ|بقيمة|amount|amt)\s*[:：]?\s*"# + number,
        ]
    }

    private static let balanceWords = ["رصيد", "الرصيد", "balance", "bal:", "bal ", "المتاح", "available", "avl", "الحد ", "limit"]

    private static let incomeWords = ["وارد", "واردة", "ايداع", "إيداع", "أودع", "اودع", "استلام", "مستلمة", "credited", "credit", "received", "deposit", "راتب", "salary", "إضافة", "اضافة"]
    private static let expenseWords = ["شراء", "خصم", "مدين", "سحب", "صادر", "صادرة", "دفع", "سداد", "purchase", "debit", "debited", "withdraw", "payment", "paid", "spent"]
    private static let refundWords = ["استرداد", "مسترد", "مستردة", "refund", "reversal", "عكس"]
    private static let salaryWords = ["راتب", "رواتب", "salary", "payroll"]
    private static let transferWords = ["حوال", "تحويل", "transfer"]

    /// الكلمات المفتاحية لكل فئة (بالترتيب).
    static let keywordMap: [(String, [String])] = [
        ("coffee", ["coffee", "cafe", "café", "starbucks", "dunkin", "barn's", "barns", "costa", "tim hortons", "half million", "dose", "brew", "كوفي", "قهوة", "قهوه", "ستاربكس", "دانكن", "بارنز", "كافيه", "كافي", "كوستا", "هاف مليون", "تيم هورتنز", "محمصة"]),
        ("food", ["restaurant", "mcdonald", "kfc", "albaik", "al baik", "burger", "pizza", "shawarma", "hungerstation", "hunger station", "jahez", "mrsool", "marsool", "toyou", "keeta", "kudu", "herfy", "maestro", "subway", "مطعم", "مطاعم", "البيك", "ماكدونالدز", "برجر", "بيتزا", "شاورما", "هنقرستيشن", "جاهز", "مرسول", "كيتا", "كودو", "هرفي", "صب واي", "مندي", "مشويات"]),
        ("grocery", ["panda", "danube", "tamimi", "carrefour", "lulu", "othaim", "farm superstore", "nesto", "supermarket", "hypermarket", "market", "بنده", "الدانوب", "التميمي", "كارفور", "لولو", "العثيم", "المزرعة", "نستو", "سوبرماركت", "هايبر", "تموينات", "بقالة", "بقاله", "ماركت"]),
        ("fuel", ["sasco", "aldrees", "petromin", "naft", "fuel", "petrol", "gas station", "ساسكو", "الدريس", "بترومين", "نفط", "محطة", "وقود", "بنزين"]),
        ("transport", ["uber", "careem", "bolt", "jeeny", "metro", "sar train", "parking", "أوبر", "اوبر", "كريم", "جيني", "مترو", "قطار", "مواقف"]),
        ("shopping", ["noon", "amazon", "shein", "namshi", "jarir", "extra", "ikea", "centrepoint", "max fashion", "h&m", "zara", "نون", "امازون", "أمازون", "شي ان", "نمشي", "جرير", "اكسترا", "ايكيا", "سنتربوينت", "زارا"]),
        ("bills", ["saudi electricity", "electricity", "national water", "sadad", "كهرباء", "المياه", "مياه", "سداد فاتورة", "فاتورة"]),
        ("telecom", ["stc", "mobily", "zain", "salam", "virgin mobile", "اس تي سي", "موبايلي", "زين", "سلام موبايل"]),
        ("health", ["pharmacy", "nahdi", "al-dawaa", "aldawaa", "hospital", "clinic", "medical", "صيدلية", "صيدليه", "النهدي", "الدواء", "مستشفى", "عيادة", "مستوصف", "طبي"]),
        ("entertainment", ["netflix", "shahid", "spotify", "anghami", "playstation", "steam", "cinema", "vox", "muvi", "osn", "نتفلكس", "شاهد", "سبوتيفاي", "انغامي", "سينما", "بلايستيشن"]),
        ("travel", ["saudia", "flynas", "flyadeal", "booking.com", "airbnb", "hotel", "almosafer", "السعودية للطيران", "طيران", "فندق", "المسافر"]),
        ("education", ["udemy", "coursera", "school", "university", "academy", "مدرسة", "جامعة", "دورة", "أكاديمية", "اكاديمية", "مكتبة"]),
    ]

    // MARK: Public

    static func parse(_ raw: String, rules: [RuleLite]) -> ParsedSMS? {
        let text = Money.normalizeDigits(raw)
        guard let amount = findAmount(in: text), amount > 0 else { return nil }
        let lower = text.lowercased()
        let income = detectIncome(lower)
        let merchant = findMerchant(in: text, isIncome: income)
        let category = guessCategory(merchant: merchant, fullText: text, isIncome: income, rules: rules)
        return ParsedSMS(amount: amount, isIncome: income, categoryKey: category, merchant: merchant)
    }

    static func normalizeMerchant(_ s: String) -> String {
        let lowered = Money.normalizeDigits(s).lowercased()
        let cleaned = lowered.unicodeScalars.map { CharacterSet.decimalDigits.contains($0) || "#*-_/\\|".unicodeScalars.contains($0) ? " " : String($0) }.joined()
        return cleaned.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func guessCategory(merchant: String, fullText: String, isIncome: Bool, rules: [RuleLite]) -> String {
        let m = normalizeMerchant(merchant)
        let t = fullText.lowercased()

        // ١) القواعد اللي تعلّمها التطبيق منك
        if m.count >= 2 {
            for rule in rules where !rule.keyword.isEmpty {
                guard incomeCategoryKeys.contains(rule.categoryKey) == isIncome else { continue }
                if m == rule.keyword || m.contains(rule.keyword) || (m.count >= 3 && rule.keyword.contains(m)) {
                    return rule.categoryKey
                }
            }
        }

        // ٢) الدخل
        if isIncome {
            if refundWords.contains(where: { t.contains($0) }) { return "refund" }
            if salaryWords.contains(where: { t.contains($0) }) { return "salary" }
            return "transfer_in"
        }

        // ٣) المصاريف حسب اسم المحل ثم نص الرسالة
        let mLower = merchant.lowercased()
        for (key, words) in keywordMap where words.contains(where: { mLower.contains($0) }) {
            return key
        }
        if ["سحب", "صراف", "atm", "withdraw"].contains(where: { t.contains($0) }) { return "cash" }
        if transferWords.contains(where: { t.contains($0) }) { return "transfer_out" }
        for (key, words) in keywordMap where words.contains(where: { t.contains($0) }) {
            return key
        }
        return "other_exp"
    }

    // MARK: Private

    private static func isBalanceLine(_ line: String) -> Bool {
        let l = line.lowercased()
        return balanceWords.contains(where: { l.contains($0) })
    }

    static func findAmount(in text: String) -> Int? {
        let lines = text.components(separatedBy: CharacterSet.newlines)
        for line in lines where !isBalanceLine(line) {
            if let a = amount(inLine: line) { return a }
        }
        // رسالة بسطر واحد: نقطع النص عند كلمة "الرصيد"
        var head = text
        let lowerText = text.lowercased()
        for word in balanceWords {
            if let r = lowerText.range(of: word) {
                let offset = lowerText.distance(from: lowerText.startIndex, to: r.lowerBound)
                let candidate = String(text.prefix(offset))
                if candidate.count < head.count { head = candidate }
            }
        }
        return amount(inLine: head)
    }

    private static func amount(inLine line: String) -> Int? {
        for p in amountPatterns {
            if let cap = firstCapture(p, in: line), let v = Money.parseHalalas(cap), v > 0 {
                return v
            }
        }
        return nil
    }

    private static func detectIncome(_ lower: String) -> Bool {
        if refundWords.contains(where: { lower.contains($0) }) { return true }
        let inc = incomeWords.contains(where: { lower.contains($0) })
        let exp = expenseWords.contains(where: { lower.contains($0) })
        return inc && !exp
    }

    private static func findMerchant(in text: String, isIncome: Bool) -> String {
        let placeKeys = #"(?:لدى|لدي|عند|التاجر|المتجر|اسم التاجر|merchant|at|إلى|الى|to)"#
        let fromKeys = #"(?:من|from|المرسل|sender)"#
        let ordered = isIncome ? [fromKeys, placeKeys] : [placeKeys, fromKeys]

        for keys in ordered {
            // مع نقطتين  "لدى: STARBUCKS"
            let withColon = #"(?:^|[\s;,])"# + keys + #"\s*[:：]\s*([^\n;]+)"#
            // بدون نقطتين  "at STARBUCKS"
            let noColon = #"(?:^|[\s;,])"# + keys + #"\s+([^\n;:]+)"#
            for p in [withColon, noColon] {
                for cap in allCaptures(p, in: text) {
                    let cleaned = cleanMerchant(cap)
                    if !cleaned.isEmpty { return cleaned }
                }
            }
        }
        return ""
    }

    private static func cleanMerchant(_ s: String) -> String {
        var c = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // نشيل المبالغ والتواريخ اللي ممكن تلتصق بالاسم
        if let r = c.range(of: #"\s+(?:في|on|بتاريخ|بـ|ب |sar|ر\.س|[0-9]{1,2}[/-][0-9]{1,2}).*$"#, options: [.regularExpression, .caseInsensitive]) {
            c.removeSubrange(r)
        }
        c = c.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        // نتجاهل أرقام الحسابات والبطاقات (أرقام ونجوم بس)
        let letters = c.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        if letters.count < 2 { return "" }
        if c.lowercased().hasPrefix("sar") { return "" }
        return String(c.prefix(40))
    }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
    }

    private static func firstCapture(_ pattern: String, in s: String) -> String? {
        guard let re = regex(pattern) else { return nil }
        let range = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, options: [], range: range),
              m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    private static func allCaptures(_ pattern: String, in s: String) -> [String] {
        guard let re = regex(pattern) else { return [] }
        let range = NSRange(s.startIndex..., in: s)
        return re.matches(in: s, options: [], range: range).compactMap { m in
            guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: s) else { return nil }
            return String(s[r])
        }
    }
}
