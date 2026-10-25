import Foundation
import CoreGraphics

/// 三件套导出编排：静默写入目标目录下「签名」子文件夹，PDF/SVG/PNG 同名。
enum VectorExporter {
    enum ExportError: LocalizedError {
        case emptyCanvas
        case renderFailed
        case invalidSVG(String)
        case cannotCreateDirectory(Error)

        var errorDescription: String? {
            switch self {
            case .emptyCanvas: return String(localized: "画布为空，先完成一次签名再导出", locale: L10n.locale)
            case .renderFailed: return String(localized: "位图渲染失败，请重试", locale: L10n.locale)
            case .invalidSVG(let reason): return String(localized: "生成的 SVG 校验未通过：\(reason)", locale: L10n.locale)
            case .cannotCreateDirectory(let error): return String(localized: "无法创建导出文件夹：\(error.localizedDescription)", locale: L10n.locale)
            }
        }
    }

    static var desktopDirectory: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    static func export(strokes: [Stroke], to directory: URL? = nil, date: Date = Date(),
                       pngBackground: CGColor? = nil) throws -> [URL] {
        guard !strokes.isEmpty else { throw ExportError.emptyCanvas }
        let folder = (directory ?? desktopDirectory).appendingPathComponent("签名", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw ExportError.cannotCreateDirectory(error)
        }
        let baseName = fileName(for: date)
        let bounding = Geometry.boundingBox(of: strokes)
        var urls: [URL] = []

        // 同秒重复导出唯一化：避免静默覆盖先前导出的文件
        var name = baseName
        var counter = 2
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(name + ".pdf").path) {
            name = baseName + "-\(counter)"
            counter += 1
        }

        let pdfURL = folder.appendingPathComponent(name + ".pdf")
        try PDFExporter.pdfData(strokes: strokes, bounding: bounding).write(to: pdfURL, options: [.atomic])
        urls.append(pdfURL)

        let svgText = SVGExporter.svg(strokes: strokes, bounding: bounding)
        try validateXML(svgText)
        let svgURL = folder.appendingPathComponent(name + ".svg")
        try svgText.write(to: svgURL, atomically: true, encoding: .utf8)
        urls.append(svgURL)

        guard let png = PNGExporter.pngData(strokes: strokes, bounding: bounding, background: pngBackground) else {
            throw ExportError.renderFailed
        }
        let pngURL = folder.appendingPathComponent(name + ".png")
        try png.write(to: pngURL, options: [.atomic])
        urls.append(pngURL)

        return urls
    }

    static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "签名-" + formatter.string(from: date)
    }

    private static func validateXML(_ string: String) throws {
        let parser = XMLParser(data: Data(string.utf8))
        guard parser.parse() else {
            throw ExportError.invalidSVG(parser.parserError?.localizedDescription
                                         ?? String(localized: "未知错误", locale: L10n.locale))
        }
    }
}
