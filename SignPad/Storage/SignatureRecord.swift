import Foundation
import CoreGraphics
import SwiftData
import AppKit

@Model
final class SignatureRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// [Stroke] 的 JSON（点位+压力+笔+颜色，完整可回放）
    var strokesJSON: Data
    var thumbnailPNG: Data
    var boundingWidth: Double
    var boundingHeight: Double

    init(strokes: [Stroke], thumbnailPNG: Data, bounding: CGRect, createdAt: Date = Date()) {
        self.id = UUID()
        self.createdAt = createdAt
        self.strokesJSON = (try? JSONEncoder().encode(strokes)) ?? Data()
        self.thumbnailPNG = thumbnailPNG
        self.boundingWidth = Double(bounding.width)
        self.boundingHeight = Double(bounding.height)
    }

    var strokes: [Stroke] {
        (try? JSONDecoder().decode([Stroke].self, from: strokesJSON)) ?? []
    }
}

enum SignatureStore {
    /// 创建 ModelContainer：默认持久化到 Application Support/SignPad/；测试用 inMemory。
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SignPad", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            configuration = ModelConfiguration(url: dir.appendingPathComponent("SignPad.storedata"))
        }
        return try ModelContainer(for: Schema([SignatureRecord.self]), configurations: [configuration])
    }

    /// 缩略图：白底，像素宽 = width，保持长宽比。
    static func thumbnailData(for strokes: [Stroke], width: CGFloat = 220) -> Data? {
        let bounding = Geometry.boundingBox(of: strokes)
        guard bounding.width > 0.5, bounding.height > 0.5 else { return nil }
        let scale = width / bounding.width
        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        return PNGExporter.pngData(strokes: strokes, bounding: bounding, scale: scale, background: white)
    }

    /// 完成签名后入库。
    @MainActor
    @discardableResult
    static func save(strokes: [Stroke], in context: ModelContext) throws -> SignatureRecord {
        let bounding = Geometry.boundingBox(of: strokes)
        let record = SignatureRecord(strokes: strokes,
                                     thumbnailPNG: thumbnailData(for: strokes) ?? Data(),
                                     bounding: bounding)
        context.insert(record)
        try context.save()
        return record
    }
}
