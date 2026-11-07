import SwiftUI
import SwiftData
import UIKit

/// تلصق رسالة البنك، والتطبيق يطلع المبلغ والمحل والفئة، وبعدين تراجعها وتحفظ.
struct PasteSMSView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var text: String
    @State private var draft: TxnDraft?
    @State private var errorText: String?
    private let autoParse: Bool

    init(text: String = "", autoParse: Bool = false) {
        _text = State(initialValue: text)
        self.autoParse = autoParse
    }

    var body: some View {
        if let d = draft {
            AddTxnView(draft: d, categoryAlreadyGuessed: true)
        } else {
            NavigationStack {
                Form {
                    Section {
                        TextEditor(text: $text)
                            .frame(minHeight: 170)
                    } header: {
                        Text("الصق رسالة البنك هنا")
                    } footer: {
                        Text("يطلع لك المبلغ واسم المحل والفئة تلقائيًا، وتقدر تعدّلها قبل الحفظ. الرسالة تبقى على جوالك فقط.")
                    }

                    Section {
                        Button {
                            if let s = UIPasteboard.general.string { text = s }
                        } label: {
                            Label("لصق من الحافظة", systemImage: "doc.on.clipboard")
                        }
                        Button {
                            parse()
                        } label: {
                            Label("اقرأ الرسالة", systemImage: "text.viewfinder")
                                .fontWeight(.bold)
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let errorText {
                        Section {
                            Label(errorText, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("رسالة بنك")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("إلغاء") { dismiss() }
                    }
                }
                .onAppear {
                    if autoParse && !text.isEmpty { parse() }
                }
            }
        }
    }

    private func parse() {
        let rules = Store.liteRules(in: ctx)
        guard let p = SMSParser.parse(text, rules: rules) else {
            errorText = "ما لقيت مبلغ في الرسالة. تأكد إنها رسالة عملية من البنك (فيها المبلغ بالريال)."
            return
        }
        errorText = nil
        draft = TxnDraft(isIncome: p.isIncome,
                         amountText: Money.plain(p.amount),
                         categoryKey: p.categoryKey,
                         merchant: p.merchant,
                         note: "",
                         date: .now,
                         rawSMS: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
