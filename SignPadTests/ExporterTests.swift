import XCTest
import PDFKit
import AppKit
@testable import SignPad

final class ExporterTests: XCTestCase {
    private var sampleStrokes: [Stroke] {
        [Stroke(pen: .fountain, color: .black, points: [
            StrokePoint(x: 0, y: 0, force: 0.3, t: 0),
            StrokePoint(x: 80, y: 30, force: 0.9, t: 0.5),
        ])]
    }
    private var sampleBounding: CGRect { Geometry.boundingBox(of: sampleStrokes) }

    private func fixedDate() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 1; c.hour = 12; c.minute = 0; c.second = 0
        return Calendar.current.date(from: c)!
    }

    // MARK: SVG

    func testSVGParsesAsXML() {
        let svg = SVGExporter.svg(strokes: sampleStrokes, bounding: sampleBounding)
        let parser = XMLParser(data: Data(svg.utf8))
        XCTAssertTrue(parser.parse(), parser.parserError?.localizedDescription ?? "SVG 非法")
    }

    func testSVGContainsStrokeAttributes() {
        let svg = SVGExporter.svg(strokes: [Stroke(pen: .ballpoint, color: .black, points: [
            StrokePoint(x: 0, y: 0, force: 0.5, t: 0), StrokePoint(x: 100, y: 0, force: 0.5, t: 1),
        ])], bounding: CGRect(x: -5, y: -5, width: 110, height: 110))
        XCTAssertTrue(svg.contains("stroke-width=\"2\""))
        XCTAssertTrue(svg.contains("stroke-linecap=\"round\""))
        XCTAssertTrue(svg.contains("M 5 105"), "原点坐标应平移并纵向翻转到 viewBox 内")
    }

    func testSVGMarkerAndPencilElements() {
        let strokes = [
            Stroke(pen: .marker, color: .black, points: [
                StrokePoint(x: 0, y: 0, force: 0.5, t: 0), StrokePoint(x: 50, y: 0, force: 0.5, t: 1),
            ]),
            Stroke(pen: .pencil, color: .black, points: [
                StrokePoint(x: 0, y: 20, force: 0.5, t: 0), StrokePoint(x: 50, y: 20, force: 0.5, t: 1),
            ]),
        ]
        let svg = SVGExporter.svg(strokes: strokes, bounding: CGRect(x: -10, y: -10, width: 80, height: 60))
        XCTAssertTrue(svg.contains("fill-opacity=\"0.4\""))
        XCTAssertTrue(svg.contains("<circle"), "铅笔颗粒应为 circle 组")
    }

    // MARK: PDF

    func testPDFIsValidSinglePage() throws {
        let data = PDFExporter.pdfData(strokes: sampleStrokes, bounding: sampleBounding)
        let doc = try XCTUnwrap(PDFDocument(data: data), "PDF 应可被 PDFKit 解析")
        XCTAssertEqual(doc.pageCount, 1)
    }

    // MARK: PNG

    func testPNGSizeIs4xAndTransparent() throws {
        let data = try XCTUnwrap(PNGExporter.pngData(strokes: sampleStrokes, bounding: sampleBounding))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(rep.pixelsWide, Int((sampleBounding.width * 4).rounded()))
        XCTAssertEqual(rep.pixelsHigh, Int((sampleBounding.height * 4).rounded()))
        let corner = rep.colorAt(x: 0, y: 0)
        XCTAssertEqual(corner?.alphaComponent ?? 1, 0, "默认背景应为透明")
    }

    func testPNGWhiteBackground() throws {
        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let data = try XCTUnwrap(PNGExporter.pngData(strokes: sampleStrokes, bounding: sampleBounding, background: white))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        let corner = try XCTUnwrap(rep.colorAt(x: 0, y: 0))
        XCTAssertGreaterThan(corner.alphaComponent, 0.99)
        // 白色校验走 RGB 分量（whiteComponent 仅对灰度色彩空间合法，RGB 像素会抛异常）
        XCTAssertGreaterThan(corner.redComponent, 0.99)
        XCTAssertGreaterThan(corner.greenComponent, 0.99)
        XCTAssertGreaterThan(corner.blueComponent, 0.99)
    }

    func testPNGContainsInkPixels() throws {
        let stroke = Stroke(pen: .ballpoint, color: .black, points: [
            StrokePoint(x: 0, y: 0, force: 0.5, t: 0),
            StrokePoint(x: 100, y: 0, force: 0.5, t: 1),
        ])
        let box = Geometry.boundingBox(of: [stroke])
        let data = try XCTUnwrap(PNGExporter.pngData(strokes: [stroke], bounding: box))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        let center = try XCTUnwrap(rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2))
        XCTAssertGreaterThan(center.alphaComponent, 0.5, "笔画中心必须有墨（回归：双重缩放导致导出空白）")
    }

    // MARK: VectorExporter 三件套

    func testExportWritesThreeFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let urls = try VectorExporter.export(strokes: sampleStrokes, to: dir, date: fixedDate())
        XCTAssertEqual(urls.count, 3)
        XCTAssertEqual(urls.map(\.pathExtension), ["pdf", "svg", "png"])
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
        XCTAssertEqual(urls[0].lastPathComponent, "签名-20260101-120000.pdf")
        // 落盘 SVG 可解析
        let svgText = try String(contentsOf: urls[1], encoding: .utf8)
        XCTAssertTrue(XMLParser(data: Data(svgText.utf8)).parse())
    }

    func testExportUniquifiesFilenames() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try VectorExporter.export(strokes: sampleStrokes, to: dir, date: fixedDate())
        let second = try VectorExporter.export(strokes: sampleStrokes, to: dir, date: fixedDate())
        XCTAssertTrue(second.allSatisfy { $0.lastPathComponent.contains("-2") }, "同秒重复导出应唯一化命名，实际: \(second.map(\.lastPathComponent))")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("签名", isDirectory: true)
                .appendingPathComponent("签名-20260101-120000.pdf").path))
    }

    func testEmptyCanvasThrows() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try VectorExporter.export(strokes: [], to: dir))
    }
}
