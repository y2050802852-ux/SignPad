import SwiftUI

/// ⌘, 设置窗口：应用内界面语言切换（跟随系统 / 简体中文 / English）。
struct SettingsView: View {
    /// 与 SignPadApp 的 @AppStorage 共享 "appLanguage" 键，任一侧写入都即时广播
    @AppStorage("appLanguage") private var appLanguage = "auto"

    var body: some View {
        Form {
            Picker("界面语言", selection: $appLanguage) {
                Text("跟随系统").tag("auto")
                Text("简体中文").tag("zh")
                Text("English").tag("en")
            }
            .pickerStyle(.radioGroup)

            Text("更改立即生效，无需重启应用")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 300)
    }
}
