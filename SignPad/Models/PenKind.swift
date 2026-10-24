import Foundation
import CoreGraphics

struct PenProfile {
    /// 恒定笔刷宽度；压感笔刷为最小宽度
    let baseWidth: CGFloat
    /// 压感笔刷最大宽度，nil 表示恒定宽度
    let maxWidth: CGFloat?
    let opacity: Double
    let usesGrain: Bool
}

enum PenKind: String, Codable, CaseIterable, Identifiable {
    case fountain = "钢笔·笔锋"
    case ballpoint = "圆珠笔"
    case marker = "马克笔"
    case pencil = "铅笔·纹理"

    var id: String { rawValue }

    var profile: PenProfile {
        switch self {
        case .fountain:  PenProfile(baseWidth: 1.5, maxWidth: 6.0, opacity: 1.0, usesGrain: false)
        case .ballpoint: PenProfile(baseWidth: 2.0, maxWidth: nil, opacity: 1.0, usesGrain: false)
        case .marker:    PenProfile(baseWidth: 8.0, maxWidth: 8.0, opacity: 0.4, usesGrain: false)
        case .pencil:    PenProfile(baseWidth: 1.2, maxWidth: nil, opacity: 0.85, usesGrain: true)
        }
    }

    /// 压力（0–1）→ 笔宽。恒定笔刷直接返回 baseWidth；压感按 gamma 0.7 缓动。
    func width(for force: CGFloat) -> CGFloat {
        guard let maxW = profile.maxWidth else { return profile.baseWidth }
        let f = min(1, max(0, force))
        return profile.baseWidth + (maxW - profile.baseWidth) * pow(f, 0.7)
    }
}
