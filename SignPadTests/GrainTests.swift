import XCTest
@testable import SignPad

final class GrainTests: XCTestCase {
    private let seed = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!

    func testDeterministicForSameSeed() {
        let path = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 50)]
        XCTAssertEqual(GrainGenerator.grains(along: path, seed: seed),
                       GrainGenerator.grains(along: path, seed: seed))
    }

    func testDifferentSeedDifferentResult() {
        let path = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 50)]
        let other = UUID(uuidString: "87654321-4321-4321-4321-210987654321")!
        XCTAssertNotEqual(GrainGenerator.grains(along: path, seed: seed),
                          GrainGenerator.grains(along: path, seed: other))
    }

    func testGrainRadiusWithinRange() {
        let path = (0..<20).map { CGPoint(x: CGFloat($0) * 3, y: 0) }
        let grains = GrainGenerator.grains(along: path, seed: seed)
        XCTAssertFalse(grains.isEmpty)
        for g in grains {
            XCTAssertGreaterThanOrEqual(g.radius, 0.15)
            XCTAssertLessThanOrEqual(g.radius, 0.45)
        }
    }

    func testShortPathYieldsNoGrains() {
        XCTAssertTrue(GrainGenerator.grains(along: [CGPoint(x: 0, y: 0)], seed: seed).isEmpty)
    }
}
