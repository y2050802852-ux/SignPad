import XCTest
import CoreGraphics
@testable import SignPad

final class PenDynamicsTests: XCTestCase {
    func testSlowerIsThicker() {
        XCTAssertGreaterThan(PenDynamics.force(velocity: 100, previous: 0.5),
                             PenDynamics.force(velocity: 1200, previous: 0.5))
    }

    func testClampsToFloorAndCeiling() {
        XCTAssertEqual(PenDynamics.force(velocity: 99999, previous: 0.15), PenDynamics.minimumForce)
        XCTAssertLessThanOrEqual(PenDynamics.force(velocity: 0, previous: 1.0), 1.0)
    }

    func testNegativeVelocityTreatedAsZero() {
        XCTAssertEqual(PenDynamics.force(velocity: -50, previous: 0.5),
                       PenDynamics.force(velocity: 0, previous: 0.5))
    }

    func testConvergesTowardTarget() {
        var f: CGFloat = 0.5
        for _ in 0..<200 { f = PenDynamics.force(velocity: 0, previous: f) }
        XCTAssertGreaterThan(f, 0.95, "持续慢速应收敛到接近最粗")
    }
}
