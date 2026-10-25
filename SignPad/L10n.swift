import Foundation

enum L10n {
    /// 用户在设置中选择的语言；auto = 跟随系统
    static var locale: Locale {
        switch UserDefaults.standard.string(forKey: "appLanguage") ?? "auto" {
        case "zh": return Locale(identifier: "zh-Hans")
        case "en": return Locale(identifier: "en")
        default: return Locale.current
        }
    }
}
