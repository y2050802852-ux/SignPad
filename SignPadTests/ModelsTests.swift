import XCTest
import SwiftUI
@testable import SignPad

final class ModelsTests: XCTestCase {
    func testStrokeCodableRoundtrip() throws {
        let stroke = Stroke(pen: .fountain, color: .blue, points: [
            StrokePoint(x: 0, y: 0, force: 0.3, t: 0),
            StrokePoint(x: 50, y: 25, force: 0.9, t: 0.5),
        ])
        let data = try JSONEncoder().encode([stroke])
        let decoded = try JSONDecoder().decode([Stroke].self, from: data)
        XCTAssertEqual(decoded, [stroke])
    }

    func testWidthScaleCodableAndLegacyDecode() throws {
        let stroke = Stroke(pen: .ballpoint, color: .black,
                            points: [StrokePoint(x: 0, y: 0, force: 0.5, t: 0), StrokePoint(x: 10, y: 0, force: 0.5, t: 1)],
                            widthScale: 1.7)
        let decoded = try JSONDecoder().decode([Stroke].self, from: JSONEncoder().encode([stroke]))
        XCTAssertEqual(decoded.first?.widthScale ?? -1, 1.7, accuracy: 0.001)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode([stroke])) as! [[String: Any]]
        for i in object.indices { object[i].removeValue(forKey: "widthScale") }
        let legacy = try JSONDecoder().decode([Stroke].self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(legacy.first?.widthScale ?? -1, 1)
    }

    func testPenWidthGamma() {
        XCTAssertEqual(PenKind.ballpoint.width(for: 0.3), 2.0)   // 恒定笔刷
        XCTAssertEqual(PenKind.marker.width(for: 1.0), 8.0)
        XCTAssertEqual(PenKind.fountain.width(for: 0), 1.5, accuracy: 0.001)
        XCTAssertEqual(PenKind.fountain.width(for: 1), 6.0, accuracy: 0.001)
        let mid = PenKind.fountain.width(for: 0.5)
        XCTAssertGreaterThan(mid, 1.5)
        XCTAssertLessThan(mid, 6.0)
    }

    func testPenRawValuesAreChinese() {
        XCTAssertEqual(PenKind.fountain.rawValue, "钢笔·笔锋")
        XCTAssertEqual(PenKind.ballpoint.rawValue, "圆珠笔")
        XCTAssertEqual(PenKind.marker.rawValue, "马克笔")
        XCTAssertEqual(PenKind.pencil.rawValue, "铅笔·纹理")
    }

    func testStrokeColorFromSwiftUIColor() {
        let c = StrokeColor(Color(red: 1, green: 0, blue: 0))
        XCTAssertGreaterThan(c.red, 0.9)
        XCTAssertLessThan(c.green, 0.1)
    }

    func testPaletteHasSixEntries() {
        XCTAssertEqual(StrokeColor.palette.count, 6)
    }
}
