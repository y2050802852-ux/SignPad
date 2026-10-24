import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// SignPad 应用图标生成器：墨迹飞白 + 朱红印章。
// 结构与 SignPad InkEngine 同构：Catmull-Rom 平滑（Smooth.swift 同式）+ 法线偏移丝带
// （Geometry.ribbon 同构），图标由应用的丝带算法自渲染。
// 模板几何取自开源生态通用的 Apple Big Sur 网格：1024 画布、824×824 主体、
// 圆角 185.4、柔和投影（见 yigithanyucedag/macos-icon-generator 等）； artwork 为原创设计。

// MARK: - 模板几何

let canvas: CGFloat = 1024
let bodySize: CGFloat = 824
let bodyOrigin: CGFloat = 100
let cornerRadius: CGFloat = 185.4

let args = CommandLine.arguments
let outputDir = args.count > 1 ? args[1] : "."

func roundedRect() -> CGPath {
    CGPath(roundedRect: CGRect(x: bodyOrigin, y: bodyOrigin, width: bodySize, height: bodySize),
           cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
}

/// 归一化坐标（主体矩形内，y 向上）→ 画布点
func pt(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
    CGPoint(x: bodyOrigin + nx * bodySize, y: bodyOrigin + ny * bodySize)
}

let ctx = CGContext(data: nil, width: Int(canvas), height: Int(canvas),
                    bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// MARK: - 投影（macOS 标准柔和投影，视觉上位于图标下方）

ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 20,
              color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.3))
ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))   // 随后整片被渐变覆盖
ctx.addPath(roundedRect())
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// MARK: - 背景：垂直线性渐变 + 上部微弱白色辉光（全部裁剪进圆角矩形）

ctx.saveGState()
ctx.addPath(roundedRect())
ctx.clip()

let rgb = CGColorSpaceCreateDeviceRGB()
let bgGradient = CGGradient(colorsSpace: rgb, colors: [
    CGColor(srgbRed: 0x26 / 255, green: 0x2A / 255, blue: 0x40 / 255, alpha: 1),   // 顶部 #262A40
    CGColor(srgbRed: 0x3E / 255, green: 0x44 / 255, blue: 0x70 / 255, alpha: 1),   // 底部 #3E4470
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bgGradient,
                       start: CGPoint(x: canvas / 2, y: bodyOrigin + bodySize),
                       end: CGPoint(x: canvas / 2, y: bodyOrigin), options: [])

let glow = CGGradient(colorsSpace: rgb, colors: [
    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.05),
    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0),
] as CFArray, locations: [0, 1])!
let glowCenter = CGPoint(x: canvas / 2, y: bodyOrigin + bodySize * 0.7)
ctx.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0,
                       endCenter: glowCenter, endRadius: 480, options: [])

// MARK: - 墨迹飞白（白色丝带，Catmull-Rom + 法线偏移，宽 56 → 16 渐细）

let controls = [pt(0.16, 0.52), pt(0.30, 0.78), pt(0.50, 0.50), pt(0.68, 0.68), pt(0.84, 0.55)]
let subdivisions = 24

// Catmull-Rom（与 Smooth.catmullRom 同式：端点钳制，曲线过端点无过冲）
var centerline: [CGPoint] = []
if controls.count > 1 {
    for i in 0..<(controls.count - 1) {
        let p0 = controls[max(i - 1, 0)]
        let p1 = controls[i]
        let p2 = controls[i + 1]
        let p3 = controls[min(i + 2, controls.count - 1)]
        for s in 0..<subdivisions {
            let t = CGFloat(s) / CGFloat(subdivisions)
            func cr(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                let t2 = t * t, t3 = t2 * t
                return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
            }
            centerline.append(CGPoint(x: cr(p0.x, p1.x, p2.x, p3.x), y: cr(p0.y, p1.y, p2.y, p3.y)))
        }
    }
    centerline.append(controls[controls.count - 1])
}

// 半宽沿程线性渐细：60 → 18
func halfWidth(at index: Int) -> CGFloat {
    let t = CGFloat(index) / CGFloat(centerline.count - 1)
    let width = 60 * (1 - t) + 18 * t
    return width / 2
}

// 法线偏移丝带（与 Geometry.ribbon 同构）：切向取邻点差分，法线 (-dy, dx)
var left: [CGPoint] = []
var right: [CGPoint] = []
for i in centerline.indices {
    let p = centerline[i]
    let prev = centerline[max(i - 1, 0)]
    let next = centerline[min(i + 1, centerline.count - 1)]
    var dx = next.x - prev.x
    var dy = next.y - prev.y
    let length = max(hypot(dx, dy), 0.0001)
    dx /= length
    dy /= length
    let half = halfWidth(at: i)
    left.append(CGPoint(x: p.x - dy * half, y: p.y + dx * half))
    right.append(CGPoint(x: p.x + dy * half, y: p.y - dx * half))
}

let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
ctx.setFillColor(white)
let ribbon = CGMutablePath()
ribbon.addLines(between: left + right.reversed())
ribbon.closeSubpath()
ctx.addPath(ribbon)
ctx.fillPath()
// 圆端帽：首尾各一个圆，半径取该端半宽
for (point, index) in [(centerline.first!, 0), (centerline.last!, centerline.count - 1)] {
    let r = halfWidth(at: index)
    ctx.addEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
    ctx.fillPath()
}

// MARK: - 用户手绘印章（边缘泛洪抠底，合成于右下）

let sealSize: CGFloat = 310   // 824 主体的 ~38%，明显大于旧版 190
let sealCenterIcon = pt(0.72, 0.28)
let sealDestRect = CGRect(x: sealCenterIcon.x - sealSize / 2, y: sealCenterIcon.y - sealSize / 2,
                          width: sealSize, height: sealSize)

// 1) 加载用户手绘印章源图（300×300，不透明白底）
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let sealSourceURL = scriptDir.appendingPathComponent("seal-source.png")
guard let sealSrc = CGImageSourceCreateWithURL(sealSourceURL as CFURL, nil),
      let sealImageRaw = CGImageSourceCreateImageAtIndex(sealSrc, 0, nil) else {
    fatalError("无法加载印章源图：\(sealSourceURL.path)")
}
let sealPixel = sealImageRaw.width   // 300

// 2) 解码为可变 RGBA 缓冲
guard let sealCtx = CGContext(data: nil, width: sealPixel, height: sealPixel,
                              bitsPerComponent: 8, bytesPerRow: sealPixel * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("无法创建印章解码上下文")
}
sealCtx.draw(sealImageRaw, in: CGRect(x: 0, y: 0, width: sealPixel, height: sealPixel))
guard let buf = sealCtx.data else { fatalError("印章像素缓冲不可用") }
let px = buf.bindMemory(to: UInt8.self, capacity: sealPixel * sealPixel * 4)

@inline(__always) func nearWhite(_ p: Int) -> Bool {
    let i = p * 4
    return px[i] >= 235 && px[i + 1] >= 235 && px[i + 2] >= 235
}

// 3) 边缘泛洪抠底：从四边 BFS，所有与边界连通的近白像素 → 透明。
//    印章内部白字（落笔为凭）不与边界连通 → 完整保留；撕边轮廓保持有机形状。
let sealTotal = sealPixel * sealPixel
var cleared = [Bool](repeating: false, count: sealTotal)
var queue = [Int]()
queue.reserveCapacity(sealTotal)
for y in 0..<sealPixel {
    for x in 0..<sealPixel where x == 0 || y == 0 || x == sealPixel - 1 || y == sealPixel - 1 {
        let p = y * sealPixel + x
        if nearWhite(p) && !cleared[p] {
            cleared[p] = true
            queue.append(p)
        }
    }
}
while let p = queue.popLast() {
    let i = p * 4
    px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = 0   // 预乘：RGB 随 alpha 归零，避免合成光晕
    let x = p % sealPixel, y = p / sealPixel
    for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
    where nx >= 0 && ny >= 0 && nx < sealPixel && ny < sealPixel {
        let np = ny * sealPixel + nx
        if !cleared[np] && nearWhite(np) {
            cleared[np] = true
            queue.append(np)
        }
    }
}

// 4) 1px 羽化：与透明区相邻的像素整体（预乘 RGBA）减半，软化撕边
var feather = [Bool](repeating: false, count: sealTotal)
for y in 0..<sealPixel {
    for x in 0..<sealPixel {
        let p = y * sealPixel + x
        if cleared[p] || px[p * 4 + 3] == 0 { continue }
        for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
        where nx >= 0 && ny >= 0 && nx < sealPixel && ny < sealPixel {
            if cleared[ny * sealPixel + nx] {
                feather[p] = true
                break
            }
        }
    }
}
for p in feather.indices where feather[p] {
    for c in 0..<4 { px[p * 4 + c] = UInt8(Double(px[p * 4 + c]) * 0.5) }
}

guard let keyedSeal = sealCtx.makeImage() else { fatalError("印章抠底后无法成图") }

// 5) 合成到画布右下（正置不旋转），柔和投影使其从藏青底上浮起
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14,
              color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.35))
ctx.draw(keyedSeal, in: sealDestRect)
ctx.restoreGState()

ctx.restoreGState()   // 结束圆角裁剪

// MARK: - 输出：1024 母版 + 10 个标准尺寸

func makeImage() -> CGImage {
    guard let image = ctx.makeImage() else { fatalError("无法生成位图") }
    return image
}
let master = makeImage()

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("无法创建 PNG 目标：\(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("PNG 写入失败：\(url.path)") }
}

func scaled(_ size: Int) -> CGImage {
    guard let c = CGContext(data: nil, width: size, height: size,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("无法创建缩放上下文")
    }
    c.interpolationQuality = .high
    c.draw(master, in: CGRect(x: 0, y: 0, width: size, height: size))
    return c.makeImage()!
}

let iconsetURL = URL(fileURLWithPath: outputDir).appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (px, name) in sizes {
    writePNG(px == 1024 ? master : scaled(px), to: iconsetURL.appendingPathComponent(name))
}

print("已生成 \(sizes.count) 个尺寸 → \(iconsetURL.path)")
