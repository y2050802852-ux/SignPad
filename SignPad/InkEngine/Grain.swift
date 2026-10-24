import Foundation
import CoreGraphics

struct Grain: Equatable {
    var position: CGPoint
    var radius: CGFloat
    var alpha: Double
}

/// SplitMix64：极简确定性随机数，用于铅笔颗粒（同 seed 同结果，导出可复现）。
struct SplitMix64 {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// [0, 1)
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

/// 铅笔纹理：沿路径按弧长撒确定性颗粒圆点，无贴图、保持矢量。
enum GrainGenerator {
    static func grains(along path: [CGPoint], seed: UUID,
                       radiusRange: ClosedRange<CGFloat> = 0.15...0.45,
                       jitter: CGFloat = 0.9) -> [Grain] {
        guard path.count > 1 else { return [] }
        var rng = SplitMix64(seed: Self.seed(from: seed))
        var grains: [Grain] = []
        for i in 0..<(path.count - 1) {
            let a = path[i]
            let b = path[i + 1]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let length = hypot(dx, dy)
            guard length > 0 else { continue }
            let density = 8.0 + rng.unit() * 6.0   // 8–14 个/单位长度
            let count = max(1, Int(length * density))
            let nx = -dy / length
            let ny = dx / length
            for _ in 0..<count {
                let t = CGFloat(rng.unit())
                let offset = (CGFloat(rng.unit()) * 2 - 1) * jitter
                grains.append(Grain(
                    position: CGPoint(x: a.x + dx * t + nx * offset, y: a.y + dy * t + ny * offset),
                    radius: radiusRange.lowerBound + CGFloat(rng.unit()) * (radiusRange.upperBound - radiusRange.lowerBound),
                    alpha: 0.25 + rng.unit() * 0.45
                ))
            }
        }
        return grains
    }

    static func seed(from uuid: UUID) -> UInt64 {
        let u = uuid.uuid
        let bytes = [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7]
        var value: UInt64 = 0
        for b in bytes { value = (value << 8) | UInt64(b) }
        return value
    }
}
