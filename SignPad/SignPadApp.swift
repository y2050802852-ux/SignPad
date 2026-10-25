import SwiftUI
import SwiftData

@main
struct SignPadApp: App {
    /// 界面语言偏好：auto = 跟随系统 / zh / en（⌘, 设置中切换，与 SettingsView 共享同一 UserDefaults 键）
    @AppStorage("appLanguage") private var appLanguage = "auto"
    @State private var session = SigningSession()
    private let container: ModelContainer

    init() {
        do {
            container = try SignatureStore.makeContainer()
        } catch {
            fatalError("无法初始化签名数据库：\(error.localizedDescription)")
        }
    }

    /// 把 appLanguage 解析为实际 Locale，注入 environment(\.locale)，SwiftUI 文本随之即时切换
    private var resolvedLocale: Locale {
        switch appLanguage {
        case "zh": return Locale(identifier: "zh-Hans")
        case "en": return Locale(identifier: "en")
        default: return Locale.current
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .environment(\.locale, resolvedLocale)
                .frame(minWidth: 1240, minHeight: 680)
        }
        .modelContainer(container)

        Settings {
            SettingsView()
                .environment(\.locale, resolvedLocale)
        }
    }
}
