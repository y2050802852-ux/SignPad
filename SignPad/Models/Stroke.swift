import Foundation
import SwiftUI

struct StrokePoint: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    /// 力度 0–1；触控板无公开压力 API，由笔速合成（见 PenDynamics），落笔初始 0.7
    var force: CGFloat
    /// 相对笔画起点的秒数
    var t: CGFloat
}

struct StrokeColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    static let black = StrokeColor(red: 0.10, green: 0.10, blue: 0.12)
    static let blue = StrokeColor(red: 0.15, green: 0.35, blue: 0.85)
    static let red = StrokeColor(red: 0.85, green: 0.20, blue: 0.18)
    static let gold = StrokeColor(red: 0.78, green: 0.60, blue: 0.16)
    static let green = StrokeColor(red: 0.15, green: 0.55, blue: 0.30)
    static let purple = StrokeColor(red: 0.50, green: 0.25, blue: 0.70)

    struct PaletteEntry: Identifiable {
        let name: String
        let color: StrokeColor
        var id: String { name }
    }

    static let palette: [PaletteEntry] = [
        .init(name: "墨黑", color: .black),
        .init(name: "靛蓝", color: .blue),
        .init(name: "朱红", color: .red),
        .init(name: "鎏金", color: .gold),
        .init(name: "松绿", color: .green),
        .init(name: "青紫", color: .purple),
    ]
}

extension StrokeColor {
    /// SwiftUI Color → sRGB 分量
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: Double(ns.redComponent), green: Double(ns.greenComponent), blue: Double(ns.blueComponent))
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct Stroke: Codable, Equatable {
    var id: UUID
    var pen: PenKind
    var color: StrokeColor
    /// 全局粗细倍率（0.5–3），随笔画记录，回放/导出不漂移
    var widthScale: CGFloat
    var points: [StrokePoint]

    init(pen: PenKind, color: StrokeColor, points: [StrokePoint], id: UUID = UUID(), widthScale: CGFloat = 1) {
        self.id = id
        self.pen = pen
        self.color = color
        self.widthScale = widthScale
        self.points = points
    }

    private enum CodingKeys: String, CodingKey { case id, pen, color, widthScale, points }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        pen = try c.decode(PenKind.self, forKey: .pen)
        color = try c.decode(StrokeColor.self, forKey: .color)
        widthScale = try c.decodeIfPresent(CGFloat.self, forKey: .widthScale) ?? 1   // 旧记录无此字段
        points = try c.decode([StrokePoint].self, forKey: .points)
    }
}
