import SwiftUI
import SwiftData

@main
struct SignPadApp: App {
    @State private var session = SigningSession()
    private let container: ModelContainer

    init() {
        do {
            container = try SignatureStore.makeContainer()
        } catch {
            fatalError("无法初始化签名数据库：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .frame(minWidth: 1240, minHeight: 680)
        }
        .modelContainer(container)
    }
}
