import XCTest
@testable import SignPad

@MainActor
final class SessionTests: XCTestCase {
    private let p1 = CGPoint(x: 10, y: 10)
    private let p2 = CGPoint(x: 60, y: 30)

    func testLifecycle() {
        let s = SigningSession()
        XCTAssertEqual(s.state, .idle)
        s.beginSession()
        XCTAssertEqual(s.state, .capturing)
        s.beginStroke(at: p1, force: 0.5, time: 0)
        s.extendStroke(at: p2, force: 0.5, time: 0.1)
        s.endStroke()
        XCTAssertEqual(s.strokes.count, 1)
        s.commitSession()
        XCTAssertEqual(s.state, .idle)
        XCTAssertEqual(s.commitSession().count, 0, "idle 下提交应无效")
    }

    func testMultiStrokeKeepsPerStrokePenAndColor() {
        let s = SigningSession()
        s.beginSession()
        s.currentPen = .ballpoint
        s.beginStroke(at: p1, force: 0.5, time: 0)
        s.extendStroke(at: p2, force: 0.5, time: 0.1)
        s.endStroke()
        s.currentPen = .marker
        s.currentColor = .red
        s.beginStroke(at: p2, force: 0.5, time: 1)
        s.extendStroke(at: CGPoint(x: 90, y: 30), force: 0.5, time: 1.1)
        s.endStroke()
        XCTAssertEqual(s.strokes.count, 2)
        XCTAssertEqual(s.strokes[0].pen, .ballpoint)
        XCTAssertEqual(s.strokes[1].pen, .marker)
        XCTAssertEqual(s.strokes[1].color, .red)
    }

    func testJitterFiltered() {
        let s = SigningSession()
        s.beginSession()
        s.beginStroke(at: p1, force: 0.5, time: 0)
        s.extendStroke(at: CGPoint(x: 10.4, y: 10.2), force: 0.5, time: 0.02) // <1pt
        s.endStroke()
        XCTAssertTrue(s.strokes.isEmpty, "单点且无有效移动的笔画应被丢弃")
    }

    func testUndoAndClear() {
        let s = SigningSession()
        XCTAssertFalse(s.canUndo)
        s.beginSession()
        s.beginStroke(at: p1, force: 0.5, time: 0)
        s.extendStroke(at: p2, force: 0.5, time: 0.1)
        s.endStroke()
        XCTAssertTrue(s.canUndo)
        s.undo()
        XCTAssertTrue(s.strokes.isEmpty)
        XCTAssertFalse(s.canUndo)
        s.beginSession()
        s.beginStroke(at: p1, force: 0.5, time: 0)
        s.extendStroke(at: p2, force: 0.5, time: 0.1)
        s.endStroke()
        s.commitSession()
        XCTAssertEqual(s.state, .idle)
        XCTAssertTrue(s.canUndo, "普通态下也应可撤销")
        s.undo()
        XCTAssertTrue(s.strokes.isEmpty, "普通态撤销应移除笔画")
    }

    func testClearWorksInIdleAndCapture() {
        let s = SigningSession()
        s.clear() // 空画布 clear 无效，不崩溃
        s.beginSession()
        s.beginStroke(at: p1, force: 0.5, time: 0)
        s.extendStroke(at: p2, force: 0.5, time: 0.1)
        s.endStroke()
        s.commitSession()
        XCTAssertEqual(s.strokes.count, 1, "完成后画布保留显示")
        s.clear()
        XCTAssertTrue(s.strokes.isEmpty, "普通态也应可清空")
        s.beginSession()
        s.beginStroke(at: p1, force: 0.5, time: 0)
        s.extendStroke(at: p2, force: 0.5, time: 0.1)
        s.endStroke()
        XCTAssertEqual(s.strokes.count, 1)
        s.clear()
        XCTAssertTrue(s.strokes.isEmpty, "捕获态下清空同样有效")
    }

    func testCompleteCallback() {
        let s = SigningSession()
        var received: [Stroke]?
        s.onComplete = { received = $0 }
        s.beginSession()
        s.beginStroke(at: p1, force: 0.5, time: 0)
        s.extendStroke(at: p2, force: 0.5, time: 0.1)
        s.endStroke()
        s.commitSession()
        XCTAssertEqual(received?.count, 1)
    }

    func testCommitEmptySessionSkipsSave() {
        let s = SigningSession()
        var called = false
        s.onComplete = { _ in called = true }
        s.beginSession()
        XCTAssertTrue(s.commitSession().isEmpty)
        XCTAssertFalse(called, "空会话提交不应触发入库回调")
        XCTAssertEqual(s.state, .idle)
    }

    func testBeginSessionKeepsStrokes() {
        let s = SigningSession()
        s.beginSession()
        s.beginStroke(at: p1, force: 0.5, time: 0)
        s.extendStroke(at: p2, force: 0.5, time: 0.1)
        s.endStroke()
        s.commitSession()
        XCTAssertEqual(s.strokes.count, 1)
        s.beginSession()
        XCTAssertEqual(s.state, .capturing)
        XCTAssertEqual(s.strokes.count, 1, "再次开始不应清空画布")
    }

    func testLoadIntoCanvasStaysIdle() {
        let s = SigningSession()
        let strokes = [Stroke(pen: .pencil, color: .gold, points: [
            StrokePoint(x: 0, y: 0, force: 0.5, t: 0),
            StrokePoint(x: 10, y: 0, force: 0.5, t: 0.1),
        ])]
        s.loadIntoCanvas(strokes: strokes)
        XCTAssertEqual(s.state, .idle, "历史载入应保持普通态")
        XCTAssertEqual(s.strokes, strokes)
        s.beginSession()
        let other = [Stroke(pen: .marker, color: .black, points: [
            StrokePoint(x: 5, y: 5, force: 0.5, t: 0),
            StrokePoint(x: 15, y: 5, force: 0.5, t: 0.1),
        ])]
        s.loadIntoCanvas(strokes: other)
        XCTAssertEqual(s.state, .capturing)
        XCTAssertEqual(s.strokes, strokes, "捕获态中历史载入应被忽略")
    }
}
