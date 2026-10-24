import Foundation
import CoreGraphics

/// 笔锋动力学：AppKit 触控板不暴露按压压力（NSTouch 无 force），
/// 以笔速合成为 0–1 力度供变宽笔刷使用——手速越慢笔画越粗。
enum PenDynamics {
    /// 零力度起点：笔速达到该值(pt/s)时力度取下限
    static let fullThinVelocity: CGFloat = 1800
    /// 力度下限
    static let minimumForce: CGFloat = 0.15
    /// EMA 平滑系数（越大跟手越快、越抖）
    static let smoothing: CGFloat = 0.35

    /// velocity: 当前采样笔速(pt/s)；previous: 上一采样力度。
    static func force(velocity: CGFloat, previous: CGFloat) -> CGFloat {
        let v = max(0, velocity)
        let target = max(minimumForce, 1 - v / fullThinVelocity)
        let smoothed = previous + (target - previous) * smoothing
        return min(1, max(minimumForce, smoothed))
    }
}
