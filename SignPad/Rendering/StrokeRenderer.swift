import Foundation
import CoreGraphics

/// 把笔画绘制进 CGContext。连续同 opacity 的笔画合入同一透明图层：图层内先画满
/// 不透明内容，再按该 opacity 整体合成，保证半透明笔刷（马克笔）段间与跨笔画
/// 重叠处颜色均匀（重叠区 alpha 与单层区一致，不会叠深）。
enum StrokeRenderer {
    /// 几何缓存：笔画进行中点数严格递增、结束后不变，
    /// 因此 (id, 点数) 命中即几何相同。超上限整体清空（签名场景足够）。
    /// 线程安全：仅主线程访问（画布绘制、导出按钮、保存缩略图均在主线程调用）。
    private static var geometryCache: [UUID: (count: Int, geometry: StrokeGeometry)] = [:]
    private static let cacheLimit = 400

    private static func cachedGeometry(for stroke: Stroke) -> StrokeGeometry {
        if let hit = geometryCache[stroke.id], hit.count == stroke.points.count {
            return hit.geometry
        }
        let geometry = Geometry.makeGeometry(for: stroke)
        if geometryCache.count > cacheLimit { geometryCache.removeAll(keepingCapacity: true) }
        geometryCache[stroke.id] = (stroke.points.count, geometry)
        return geometry
    }

    static func draw(_ strokes: [Stroke], in context: CGContext, bounds: CGRect) {
        context.saveGState()
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        var group: (opacity: Double, strokes: [Stroke])?
        for stroke in strokes {
            let opacity = stroke.pen.profile.opacity
            if group?.opacity == opacity {
                group?.strokes.append(stroke)
            } else {
                flush(group, in: context)
                group = (opacity, [stroke])
            }
        }
        flush(group, in: context)
        context.restoreGState()
    }

    /// 把一组同 opacity 的笔画画入独立透明图层后整体合成。
    private static func flush(_ group: (opacity: Double, strokes: [Stroke])?, in context: CGContext) {
        guard let group else { return }
        context.saveGState()
        context.setAlpha(CGFloat(group.opacity))
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        for stroke in group.strokes {
            let geometry = cachedGeometry(for: stroke)
            let color = CGColor(srgbRed: stroke.color.red, green: stroke.color.green,
                                blue: stroke.color.blue, alpha: 1)
            drawGeometry(geometry, color: color, in: context)
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func drawGeometry(_ g: StrokeGeometry, color: CGColor, in context: CGContext) {
        context.setStrokeColor(color)
        context.setFillColor(color)
        if let ribbon = g.ribbon {
            let path = CGMutablePath()
            path.addLines(between: ribbon)
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            for cap in g.endCaps {
                context.addEllipse(in: CGRect(x: cap.center.x - cap.radius, y: cap.center.y - cap.radius,
                                              width: cap.radius * 2, height: cap.radius * 2))
                context.fillPath()
            }
        } else if let first = g.centerline.first {
            let path = CGMutablePath()
            path.move(to: first)
            path.addLines(between: g.centerline)
            context.addPath(path)
            context.setLineWidth(g.strokeWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
        }
        if let grains = g.grains {
            for grain in grains {
                context.setFillColor(color.copy(alpha: CGFloat(grain.alpha)) ?? color)
                context.fillEllipse(in: CGRect(x: grain.position.x - grain.radius, y: grain.position.y - grain.radius,
                                               width: grain.radius * 2, height: grain.radius * 2))
            }
        }
    }
}
