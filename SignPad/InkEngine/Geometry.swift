import Foundation
import CoreGraphics

/// 一条笔画的矢量几何——笔刷类型到具体形状的唯一映射处。
struct StrokeGeometry {
    struct EndCap: Equatable {
        var center: CGPoint
        var radius: CGFloat
    }
    var centerline: [CGPoint]
    /// 等宽笔刷的描边宽度；变宽笔刷为 0
    var strokeWidth: CGFloat
    /// 变宽笔刷的丝带填充多边形（左半 + 右半逆序，隐式闭合）
    var ribbon: [CGPoint]?
    var endCaps: [EndCap] = []
    /// 铅笔颗粒
    var grains: [Grain]?
    var opacity: Double
}

enum Geometry {
    /// InkEngine 管线总入口：笔画 → 矢量几何。
    static func makeGeometry(for stroke: Stroke) -> StrokeGeometry {
        let profile = stroke.pen.profile
        let smoothed = Smooth.catmullRom(points: stroke.points)
        let centers = smoothed.map { CGPoint(x: $0.x, y: $0.y) }
        let scale = stroke.widthScale
        if profile.maxWidth != nil {
            let ribbon = Self.ribbon(points: smoothed, pen: stroke.pen, scale: scale)
            let caps = [
                StrokeGeometry.EndCap(center: centers.first ?? .zero,
                                      radius: stroke.pen.width(for: smoothed.first?.force ?? 0.5) * scale / 2),
                StrokeGeometry.EndCap(center: centers.last ?? .zero,
                                      radius: stroke.pen.width(for: smoothed.last?.force ?? 0.5) * scale / 2),
            ]
            return StrokeGeometry(centerline: centers, strokeWidth: 0, ribbon: ribbon,
                                  endCaps: caps, grains: nil, opacity: profile.opacity)
        }
        let grains = profile.usesGrain
            ? GrainGenerator.grains(along: centers, seed: stroke.id,
                                    radiusRange: (0.15 * scale)...(0.45 * scale))
            : nil
        return StrokeGeometry(centerline: centers, strokeWidth: profile.baseWidth * scale, ribbon: nil,
                              endCaps: [], grains: grains, opacity: profile.opacity)
    }

    /// 沿中心线按各点压力求法线偏移，生成两侧等距的丝带多边形（左半正序 + 右半逆序）。
    static func ribbon(points: [StrokePoint], pen: PenKind, scale: CGFloat) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        guard points.count > 1 else {
            let p = points[0]
            let half = pen.width(for: p.force) * scale / 2
            return [
                CGPoint(x: p.x - half, y: p.y), CGPoint(x: p.x, y: p.y + half),
                CGPoint(x: p.x + half, y: p.y), CGPoint(x: p.x, y: p.y - half),
            ]
        }
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in points.indices {
            let p = points[i]
            let prev = points[max(i - 1, 0)]
            let next = points[min(i + 1, points.count - 1)]
            var dx = next.x - prev.x
            var dy = next.y - prev.y
            let length = max(hypot(dx, dy), 0.0001)
            dx /= length
            dy /= length
            let half = pen.width(for: p.force) * scale / 2
            left.append(CGPoint(x: p.x - dy * half, y: p.y + dx * half))
            right.append(CGPoint(x: p.x + dy * half, y: p.y - dx * half))
        }
        return left + right.reversed()
    }

    /// 全部笔画的联合包围盒：含笔画半宽 + 最大边 2% 内边距（最少 2pt）。
    /// 铅笔额外外扩 0.9 + 0.45×倍率，覆盖颗粒抖动 ±0.9 与最大颗粒半径 0.45×倍率。
    static func boundingBox(of strokes: [Stroke]) -> CGRect {
        guard !strokes.isEmpty else { return .zero }
        var union: CGRect?
        for stroke in strokes {
            let profile = stroke.pen.profile
            let halfWidth = ((profile.maxWidth ?? profile.baseWidth) * stroke.widthScale) / 2
                + (profile.usesGrain ? 0.9 + 0.45 * stroke.widthScale : 0)
            let points = stroke.points.map { CGPoint(x: $0.x, y: $0.y) }
            guard var rect = rectOf(points: points) else { continue }
            rect = rect.insetBy(dx: -halfWidth, dy: -halfWidth)
            union = union?.union(rect) ?? rect
        }
        guard var box = union else { return .zero }
        let pad = max(max(box.width, box.height) * 0.02, 2)
        return box.insetBy(dx: -pad, dy: -pad)
    }

    private static func rectOf(points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
