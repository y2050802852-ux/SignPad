import Foundation
import CoreGraphics
import Observation

/// 一次签名会话的状态机：idle →（开始签名/继续编辑）→ capturing →（完成）→ idle。
/// 开始签名不清空画布（从当前内容继续，新建请先「清空」）；完成后画布保留显示；Esc/回车/按钮均走 commitSession。
@Observable
@MainActor
final class SigningSession {
    enum State: Equatable { case idle, capturing }

    private(set) var state: State = .idle
    private(set) var strokes: [Stroke] = []
    private(set) var activeStroke: Stroke?
    var currentPen: PenKind = .fountain
    var currentColor = StrokeColor.black
    /// 全局笔画粗细倍率（0.5–3，UI 滑杆调节），随每笔记录
    var widthScale: CGFloat = 1

    /// 笔迹变化回调（供 NSView 标记重绘）
    var onStrokesChanged: (() -> Void)?
    /// 完成签名回调（供历史入库）
    var onComplete: (([Stroke]) -> Void)?

    var canUndo: Bool { activeStroke == nil && !strokes.isEmpty }
    var canComplete: Bool { canUndo }
    var canClear: Bool { !strokes.isEmpty || activeStroke != nil }

    private var strokeStartTime: TimeInterval = 0

    /// 进入捕获态。不清空画布——「开始签名/继续编辑」都从当前画布内容继续；新建请先「清空」。
    func beginSession() {
        state = .capturing
        onStrokesChanged?()
    }

    @discardableResult
    func commitSession() -> [Stroke] {
        guard state == .capturing, activeStroke == nil else { return [] }
        state = .idle
        let finished = strokes
        // 空会话（如空画布上按 Esc）= 取消，不入库
        if !finished.isEmpty { onComplete?(finished) }
        onStrokesChanged?()
        return finished
    }

    /// 取消捕获态但不入库（窗口失焦等安全路径），画布保留当前内容。
    func cancelSession() {
        guard state == .capturing else { return }
        state = .idle
        activeStroke = nil
        onStrokesChanged?()
    }

    /// 从历史载入签名到画布（保持普通态，由用户点「继续编辑」进入书写）。捕获态中忽略。
    func loadIntoCanvas(strokes: [Stroke]) {
        guard state == .idle else { return }
        self.strokes = strokes
        activeStroke = nil
        onStrokesChanged?()
    }

    func beginStroke(at point: CGPoint, force: CGFloat, time: TimeInterval) {
        guard state == .capturing, activeStroke == nil else { return } // 第二根手指忽略
        strokeStartTime = time
        activeStroke = Stroke(pen: currentPen, color: currentColor,
                              points: [StrokePoint(x: point.x, y: point.y, force: force, t: 0)],
                              widthScale: widthScale)
        onStrokesChanged?()
    }

    func extendStroke(at point: CGPoint, force: CGFloat, time: TimeInterval) {
        guard var stroke = activeStroke, let last = stroke.points.last else { return }
        guard hypot(point.x - last.x, point.y - last.y) >= 1 else { return } // 过滤微抖动
        stroke.points.append(StrokePoint(x: point.x, y: point.y, force: force,
                                         t: CGFloat(time - strokeStartTime)))
        activeStroke = stroke
        onStrokesChanged?()
    }

    func endStroke() {
        guard let stroke = activeStroke else { return }
        if stroke.points.count >= 2 { strokes.append(stroke) }
        activeStroke = nil
        onStrokesChanged?()
    }

    func undo() {
        guard canUndo else { return }
        strokes.removeLast()
        onStrokesChanged?()
    }

    func clear() {
        guard canClear else { return }
        strokes = []
        activeStroke = nil
        onStrokesChanged?()
    }
}
