import AppKit

/// 签名画布：仅展示渲染 + 捕获态 UI（呼吸边框/光标/全窗口捕获层）。
/// 触摸由覆盖全窗口的 CaptureOverlayView 接收，白布本身 display-only。
final class CanvasView: NSView {
    var session: SigningSession? {
        didSet { syncCaptureUI() }
    }

    private var borderLayer: CALayer?
    private var canvasRect: NSRect { bounds.insetBy(dx: 12, dy: 12) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private var resignObserver: NSObjectProtocol?

    private func commonInit() {
        acceptsTouchEvents = true
        // 触控板裸触摸是 .indirect 类型；显式声明两种类型确保投递（终审建议仅 .direct 是错误的）
        allowedTouchTypes = [.direct, .indirect]
        wantsLayer = true
        // 窗口失焦安全路径：cmd-tab 离开时取消捕获，避免光标被全局隐藏
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                                                object: nil, queue: .main) { [weak self] note in
            guard let self, let resigned = note.object as? NSWindow, resigned === self.window else { return }
            self.session?.cancelSession()
        }
    }

    deinit {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
    }

    /// NSView 原点在左下，触控板 normalizedPosition 的 y=0 也在底部，直接线性映射。
    /// （normalizedPosition 是 0–1 的单位坐标，直接铺到画布矩形上。）
    func canvasPoint(for touch: NSTouch) -> CGPoint {
        let n = touch.normalizedPosition
        return CGPoint(x: n.x * canvasRect.width + canvasRect.minX,
                       y: n.y * canvasRect.height + canvasRect.minY)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: canvasRect, xRadius: 10, yRadius: 10).fill()
        guard let session, let context = NSGraphicsContext.current?.cgContext else { return }
        var strokes = session.strokes
        if let active = session.activeStroke { strokes.append(active) }
        guard !strokes.isEmpty else { return }
        StrokeRenderer.draw(strokes, in: context, bounds: canvasRect)
    }

    private var captureUIActive = false
    private var captureOverlay: CaptureOverlayView?
    private var cursorHiddenByCapture = false

    /// 捕获态：指针冻结 + 窗口服务器级光标隐藏 + 呼吸高亮边框 + 全窗口透明捕获层；退出时全部恢复。
    private func syncCaptureUI() {
        needsDisplay = true
        guard let session else { return }
        let capturing = session.state == .capturing
        guard capturing != captureUIActive else { return }   // 状态未翻转时不重入
        captureUIActive = capturing
        if capturing {
            let border = CALayer()
            border.frame = canvasRect
            border.cornerRadius = 10
            border.borderWidth = 2.5
            border.borderColor = NSColor.controlAccentColor.cgColor
            let breath = CABasicAnimation(keyPath: "opacity")
            breath.fromValue = 1.0
            breath.toValue = 0.25
            breath.duration = 0.9
            breath.autoreverses = true
            breath.repeatCount = .infinity
            border.add(breath, forKey: "breath")
            layer?.addSublayer(border)
            borderLayer = border
            if cursorHiddenByCapture == false {
                cursorHiddenByCapture = (CGDisplayHideCursor(CGMainDisplayID()) == .success)
            }
            // 冻结指针：书写期间鼠标移动与指针解耦，指针停在窗口内原位，
            // 不可能划到 Dock/菜单栏等其他进程区域导致光标复活
            _ = CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
            if captureOverlay == nil, let contentView = window?.contentView {
                let overlay = CaptureOverlayView(frame: contentView.bounds)
                overlay.autoresizingMask = [.width, .height]
                overlay.canvas = self
                contentView.addSubview(overlay, positioned: .above, relativeTo: nil)
                captureOverlay = overlay
            }
        } else {
            borderLayer?.removeFromSuperlayer()
            borderLayer = nil
            _ = CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
            if cursorHiddenByCapture {
                CGDisplayShowCursor(CGMainDisplayID())
                cursorHiddenByCapture = false
            }
            captureOverlay?.removeFromSuperview()
            captureOverlay = nil
        }
    }

    override func layout() {
        super.layout()
        borderLayer?.frame = canvasRect
    }
}

/// 书写态的全窗口透明捕获层：触摸不再依赖指针位置（白布仅展示）。
final class CaptureOverlayView: NSView {
    weak var canvas: CanvasView?

    private var lastCanvasPoint: CGPoint?
    private var lastTimestamp: TimeInterval = 0
    private var currentForce: CGFloat = 0.7

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        acceptsTouchEvents = true
        allowedTouchTypes = [.direct, .indirect]
    }

    override func touchesBegan(with event: NSEvent) {
        guard let canvas, canvas.session?.state == .capturing else { return }
        for touch in event.touches(for: self) {
            let point = canvas.canvasPoint(for: touch)
            lastCanvasPoint = point
            lastTimestamp = event.timestamp
            currentForce = 0.7
            canvas.session?.beginStroke(at: point, force: currentForce, time: event.timestamp)
        }
    }

    override func touchesMoved(with event: NSEvent) {
        guard let canvas, canvas.session?.state == .capturing else { return }
        for touch in event.touches(for: self) {
            let point = canvas.canvasPoint(for: touch)
            if let last = lastCanvasPoint {
                let dt = max(event.timestamp - lastTimestamp, 0.001)
                let velocity = hypot(point.x - last.x, point.y - last.y) / dt
                currentForce = PenDynamics.force(velocity: velocity, previous: currentForce)
            }
            lastCanvasPoint = point
            lastTimestamp = event.timestamp
            canvas.session?.extendStroke(at: point, force: currentForce, time: event.timestamp)
        }
    }

    override func touchesEnded(with event: NSEvent) {
        canvas?.session?.endStroke()
    }

    override func touchesCancelled(with event: NSEvent) {
        canvas?.session?.endStroke()
    }

    override func draw(_ dirtyRect: NSRect) {}   // 纯透明
}
