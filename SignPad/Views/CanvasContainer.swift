import SwiftUI

struct CanvasContainer: NSViewRepresentable {
    let session: SigningSession

    func makeNSView(context: Context) -> CanvasView {
        let view = CanvasView()
        view.session = session
        session.onStrokesChanged = { [weak view] in view?.needsDisplay = true }
        return view
    }

    func updateNSView(_ nsView: CanvasView, context: Context) {
        nsView.session = session
    }
}
