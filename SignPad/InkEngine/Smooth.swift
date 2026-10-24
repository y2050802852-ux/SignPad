import Foundation
import CoreGraphics

/// Catmull-Rom 插值平滑。端点处钳制控制点（p0=p1、p3=p2），保证曲线过端点且无端点过冲。
enum Smooth {
    /// 每对相邻点之间插入 `subdivisions` 个中间点，同时插值压力。
    static func catmullRom(points: [StrokePoint], subdivisions: Int = 8) -> [StrokePoint] {
        guard points.count > 1, subdivisions > 0 else { return points }
        var result: [StrokePoint] = []
        result.reserveCapacity((points.count - 1) * subdivisions + 1)
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            for s in 0..<subdivisions {
                let t = CGFloat(s) / CGFloat(subdivisions)
                result.append(StrokePoint(
                    x: cr(p0.x, p1.x, p2.x, p3.x, t: t),
                    y: cr(p0.y, p1.y, p2.y, p3.y, t: t),
                    force: cr(p0.force, p1.force, p2.force, p3.force, t: t),
                    t: p1.t + (p2.t - p1.t) * t
                ))
            }
        }
        result.append(points[points.count - 1])
        return result
    }

    private static func cr(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat, t: CGFloat) -> CGFloat {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
    }
}
