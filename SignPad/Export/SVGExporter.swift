import Foundation
import CoreGraphics

/// 签名 → SVG 字符串。坐标平移到 viewBox 原点。
/// 等宽笔=中心线 path + stroke 属性；变宽笔=丝带 fill path + 端帽圆；铅笔=细描边 + 颗粒 circle 组。
enum SVGExporter {
    static func svg(strokes: [Stroke], bounding: CGRect) -> String {
        let w = num(bounding.width)
        let h = num(bounding.height)
        var body = ""
        for stroke in strokes {
            let g = Geometry.makeGeometry(for: stroke)
            let rgb = "rgb(\(Int((stroke.color.red * 255).rounded())),\(Int((stroke.color.green * 255).rounded())),\(Int((stroke.color.blue * 255).rounded())))"
            let origin = bounding.origin
            if let ribbon = g.ribbon {
                body += "<path d=\"\(d(ribbon, origin: origin, height: bounding.height)) Z\" fill=\"\(rgb)\" fill-opacity=\"\(g.opacity)\"/>\n"
                for cap in g.endCaps {
                    body += "<circle cx=\"\(num(cap.center.x - origin.x))\" cy=\"\(num(svgY(cap.center.y, origin: origin, height: bounding.height)))\" r=\"\(num(cap.radius))\" fill=\"\(rgb)\" fill-opacity=\"\(g.opacity)\"/>\n"
                }
            } else if !g.centerline.isEmpty {
                body += "<path d=\"\(d(g.centerline, origin: origin, height: bounding.height))\" fill=\"none\" stroke=\"\(rgb)\" stroke-opacity=\"\(g.opacity)\" stroke-width=\"\(num(g.strokeWidth))\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n"
            }
            if let grains = g.grains, !grains.isEmpty {
                body += "<g fill=\"\(rgb)\" fill-opacity=\"\(g.opacity)\">\n"
                for grain in grains {
                    body += "<circle cx=\"\(num(grain.position.x - origin.x))\" cy=\"\(num(svgY(grain.position.y, origin: origin, height: bounding.height)))\" r=\"\(num(grain.radius))\" opacity=\"\(grain.alpha)\"/>\n"
                }
                body += "</g>\n"
            }
        }
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(w)" height="\(h)" viewBox="0 0 \(w) \(h)">
        \(body)</svg>
        """
    }

    private static func d(_ points: [CGPoint], origin: CGPoint, height: CGFloat) -> String {
        guard let first = points.first else { return "" }
        var parts = ["M \(num(first.x - origin.x)) \(num(svgY(first.y, origin: origin, height: height)))"]
        for p in points.dropFirst() {
            parts.append("L \(num(p.x - origin.x)) \(num(svgY(p.y, origin: origin, height: height)))")
        }
        return parts.joined(separator: " ")
    }

    /// 笔迹空间 y 向上，SVG 坐标系 y 向下：本地 y 翻转后输出
    private static func svgY(_ y: CGFloat, origin: CGPoint, height: CGFloat) -> CGFloat {
        height - (y - origin.y)
    }

    private static func num(_ v: CGFloat) -> String {
        let s = String(format: "%.2f", locale: nil, v)
        if s.hasSuffix(".00") { return String(s.dropLast(3)) }
        if s.hasSuffix("0") { return String(s.dropLast(1)) }
        return s
    }
}
