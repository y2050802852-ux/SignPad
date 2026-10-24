import XCTest
@testable import SignPad

final class GeometryTests: XCTestCase {
    private func horizontalStroke(_ pen: PenKind) -> Stroke {
        Stroke(pen: pen, color: .black, points: [
            StrokePoint(x: 0, y: 0, force: 0.5, t: 0),
            StrokePoint(x: 100, y: 0, force: 0.5, t: 1),
        ])
    }

    func testBallpointUsesCenterlineOnly() {
        let g = Geometry.makeGeometry(for: horizontalStroke(.ballpoint))
        XCTAssertNil(g.ribbon)
        XCTAssertNil(g.grains)
        XCTAssertEqual(g.strokeWidth, 2.0)
        XCTAssertEqual(g.opacity, 1.0, accuracy: 0.001)
    }

    func testFountainUsesRibbonWithCaps() {
        let g = Geometry.makeGeometry(for: horizontalStroke(.fountain))
        XCTAssertNotNil(g.ribbon)
        XCTAssertEqual(g.endCaps.count, 2)
        XCTAssertEqual(g.opacity, 1.0, accuracy: 0.001)
    }

    func testMarkerOpacity() {
        let g = Geometry.makeGeometry(for: horizontalStroke(.marker))
        XCTAssertEqual(g.opacity, 0.4, accuracy: 0.001)
        XCTAssertNotNil(g.ribbon)
    }

    func testPencilHasGrains() {
        let g = Geometry.makeGeometry(for: horizontalStroke(.pencil))
        XCTAssertNotNil(g.grains)
        XCTAssertFalse(g.grains?.isEmpty ?? true)
        XCTAssertEqual(g.strokeWidth, 1.2)
    }

    func testRibbonPointCountAndClosureWidth() {
        let pts = [
            StrokePoint(x: 0, y: 0, force: 1, t: 0),
            StrokePoint(x: 100, y: 0, force: 1, t: 1),
        ]
        let ribbon = Geometry.ribbon(points: pts, pen: .fountain, scale: 1)
        XCTAssertEqual(ribbon.count, pts.count * 2)
        // 水平线法线垂直：force=1 → 宽 6 → 半宽 3，第一点偏移到 y=3
        XCTAssertEqual(ribbon[0].y, 3.0, accuracy: 0.001)
    }

    func testRibbonAndBoundingBoxRespectScale() {
        let pts = [StrokePoint(x: 0, y: 0, force: 1, t: 0), StrokePoint(x: 100, y: 0, force: 1, t: 1)]
        let ribbon = Geometry.ribbon(points: pts, pen: .fountain, scale: 3)
        XCTAssertEqual(ribbon[0].y, 9.0, accuracy: 0.001)   // 6pt × 3 / 2
        let stroke = Stroke(pen: .ballpoint, color: .black, points: pts, widthScale: 3)
        let box = Geometry.boundingBox(of: [stroke])
        XCTAssertEqual(box.minX, -5.12, accuracy: 0.01)     // 半宽 3 + 106 的 2%（2.12）
    }

    func testBoundingBoxPadding() {
        let box = Geometry.boundingBox(of: [horizontalStroke(.ballpoint)])
        // 半宽 1 + 最大边 102 的 2%（2.04）= 3.04
        XCTAssertEqual(box.minX, -3.04, accuracy: 0.01)
        XCTAssertEqual(box.maxX, 103.04, accuracy: 0.01)
        XCTAssertEqual(box.minY, -3.04, accuracy: 0.01)
        XCTAssertEqual(box.maxY, 3.04, accuracy: 0.01)
    }
}
