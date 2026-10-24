import XCTest
import CoreGraphics
@testable import SignPad

final class RendererTests: XCTestCase {
    /// 手工建 RGBA 位图上下文，读取指定坐标 alpha。
    private func renderAndReadAlpha(strokes: [Stroke], size: CGSize, samples: [(Int, Int)]) -> [UInt8] {
        let w = Int(size.width), h = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        StrokeRenderer.draw(strokes, in: ctx, bounds: CGRect(origin: .zero, size: size))
        // CGBitmapContext 用户空间原点在左下角，而缓冲区首行是图像顶行：读像素时按行翻转。
        return samples.map { x, y in pixels[((h - 1 - y) * w + x) * 4 + 3] }
    }

    func testStrokePaintsPixels() {
        let stroke = Stroke(pen: .ballpoint, color: .black, points: [
            StrokePoint(x: 10, y: 10, force: 0.5, t: 0),
            StrokePoint(x: 90, y: 10, force: 0.5, t: 1),
        ])
        let alphas = renderAndReadAlpha(strokes: [stroke], size: CGSize(width: 100, height: 20), samples: [(50, 10)])
        XCTAssertGreaterThan(alphas[0], 0, "笔画中心线应有像素")
    }

    func testMarkerUniformOpacityAcrossOverlappingStrokes() {
        // 两条马克笔在 (40,12) 附近交叉。离屏图层合成下重叠区 alpha 与单层区一致（=102±4），
        // 若不做图层合成，重叠区会是 0.64 → 163。
        let horizontal = Stroke(pen: .marker, color: .black, points: [
            StrokePoint(x: 10, y: 10, force: 0.5, t: 0),
            StrokePoint(x: 80, y: 10, force: 0.5, t: 1),
        ])
        let vertical = Stroke(pen: .marker, color: .black, points: [
            StrokePoint(x: 40, y: 10, force: 0.5, t: 0),
            StrokePoint(x: 40, y: 40, force: 0.5, t: 1),
        ])
        let alphas = renderAndReadAlpha(strokes: [horizontal, vertical],
                                        size: CGSize(width: 100, height: 50),
                                        samples: [(20, 10), (40, 30), (40, 12)])
        for alpha in alphas {
            XCTAssertTrue(abs(Int(alpha) - 102) <= 4, "alpha=\(alpha)，期望 102±4（均匀 0.4）")
        }
    }
}
