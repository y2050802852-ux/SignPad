import XCTest
import SwiftData
import AppKit
@testable import SignPad

@MainActor
final class StorageTests: XCTestCase {
    private lazy var sampleStrokes: [Stroke] = [
        Stroke(pen: .ballpoint, color: .black, points: [
            StrokePoint(x: 0, y: 0, force: 0.5, t: 0),
            StrokePoint(x: 60, y: 20, force: 0.5, t: 0.4),
        ]),
    ]

    func testSaveAndFetchRoundtrip() throws {
        let container = try SignatureStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let record = try SignatureStore.save(strokes: sampleStrokes, in: context)
        let fetched = try context.fetch(FetchDescriptor<SignatureRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, record.id)
        XCTAssertEqual(fetched[0].strokes, sampleStrokes, "笔迹 JSON 往返应一致")
        XCTAssertFalse(fetched[0].thumbnailPNG.isEmpty, "缩略图应已生成")
        XCTAssertGreaterThan(fetched[0].boundingWidth, 0)
        XCTAssertGreaterThan(fetched[0].boundingHeight, 0)
    }

    func testDelete() throws {
        let container = try SignatureStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let record = try SignatureStore.save(strokes: sampleStrokes, in: context)
        context.delete(record)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<SignatureRecord>()).count, 0)
    }

    func testThumbnailHasTargetPixelWidth() throws {
        let data = try XCTUnwrap(SignatureStore.thumbnailData(for: sampleStrokes, width: 220))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(rep.pixelsWide, 220)
    }
}
