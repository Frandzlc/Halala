import SwiftUI
import SwiftData

@main
struct HalalaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Store.container)
    }
}

struct SMSPayload: Identifiable {
    let id = UUID()
    let text: String
}

struct RootView: View {
    @State private var incoming: SMSPayload?

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }
            TransactionsView()
                .tabItem { Label("العمليات", systemImage: "list.bullet.rectangle.portrait.fill") }
            StatsView()
                .tabItem { Label("الإحصائيات", systemImage: "chart.pie.fill") }
            SettingsView()
                .tabItem { Label("الإعدادات", systemImage: "gearshape.fill") }
        }
        .tint(Color(red: 0.05, green: 0.55, blue: 0.38))
        .arabic()
        // halala://sms?text=...  يفتح شاشة رسالة البنك بالنص جاهز
        .onOpenURL { url in
            guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let text = comps.queryItems?.first(where: { $0.name == "text" })?.value,
                  !text.isEmpty else { return }
            incoming = SMSPayload(text: text)
        }
        .sheet(item: $incoming) { p in
            PasteSMSView(text: p.text, autoParse: true).arabic()
        }
    }
}
