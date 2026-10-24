import Foundation
import CoreGraphics

/// 签名 → 单页 PDF（矢量，无底色）。
enum PDFExporter {
    static func pdfData(strokes: [Stroke], bounding: CGRect) -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var mediaBox = CGRect(x: 0, y: 0, width: max(1, bounding.width), height: max(1, bounding.height))
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }
        context.beginPDFPage(nil)
        StrokeRenderer.draw(strokes, in: context, bounds: bounding)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}
