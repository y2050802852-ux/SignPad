import Foundation
import CoreGraphics
import AppKit

/// 签名 → PNG 位图。scale 为像素密度倍数（@4x 高清）；background nil = 透明背景。
/// 用纯 CG 位图上下文（无 NSBitmapImageRep 的 DPI 隐式映射，杜绝双重缩放）。
enum PNGExporter {
    static func pngData(strokes: [Stroke], bounding: CGRect, scale: CGFloat = 4, background: CGColor? = nil) -> Data? {
        let width = max(1, Int((bounding.width * scale).rounded()))
        let height = max(1, Int((bounding.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setAllowsAntialiasing(true)
        context.scaleBy(x: scale, y: scale)   // 点坐标 → 像素
        if let background {
            // 位图用户空间为 (0,0)–(bounding.size)（StrokeRenderer 内部平移 -bounds.origin 对齐），
            // 不能直接填 bounding（原点为负，会漏填顶部条带）
            context.setFillColor(background)
            context.fill(CGRect(origin: .zero, size: bounding.size))
        }
        StrokeRenderer.draw(strokes, in: context, bounds: bounding)
        guard let image = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
