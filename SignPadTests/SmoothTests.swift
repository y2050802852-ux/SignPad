import XCTest
@testable import SignPad

final class SmoothTests: XCTestCase {
    func testSinglePointReturnsAsIs() {
        let p = [StrokePoint(x: 1, y: 2, force: 0.5, t: 0)]
        XCTAssertEqual(Smooth.catmullRom(points: p), p)
    }

    func testOutputCount() {
        let pts = (0..<5).map { StrokePoint(x: CGFloat($0) * 10, y: 0, force: 0.5, t: CGFloat($0)) }
        let out = Smooth.catmullRom(points: pts)
        XCTAssertEqual(out.count, (5 - 1) * 8 + 1)
    }

    func testEndpointsPreserved() {
        let pts = [StrokePoint(x: 0, y: 0, force: 0.2, t: 0), StrokePoint(x: 30, y: 40, force: 0.8, t: 1)]
        let out = Smooth.catmullRom(points: pts)
        XCTAssertEqual(out.first?.x ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(out.first?.y ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(out.last?.x ?? -1, 30, accuracy: 0.001)
        XCTAssertEqual(out.last?.y ?? -1, 40, accuracy: 0.001)
    }

    func testForceInterpolationMonotonic() {
        let pts = [StrokePoint(x: 0, y: 0, force: 0, t: 0), StrokePoint(x: 100, y: 0, force: 1, t: 1)]
        let forces = Smooth.catmullRom(points: pts).map(\.force)
        XCTAssertEqual(forces, forces.sorted())
    }
}
