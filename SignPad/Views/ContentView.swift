import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(SigningSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @State private var exportError: String?
    @State private var exportedFiles: [URL]?
    @State private var toastDismissTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                CanvasContainer(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: 700, minHeight: 380)
                captureHint
                penBar
                actionBar
            }
            Divider()
            HistorySidebar { record in
                guard session.state == .idle else { return }
                session.loadIntoCanvas(strokes: record.strokes)
            }
            .frame(width: 240)
        }
        .frame(minWidth: 1240, minHeight: 680)
        .containerBackground(for: .window) { WindowBackground() }
        .onExitCommand {
            if session.state == .capturing { session.commitSession() }
        }
        .onAppear {
            session.onComplete = { strokes in
                do {
                    _ = try SignatureStore.save(strokes: strokes, in: modelContext)
                } catch {
                    exportError = String(localized: "保存历史失败：\(error.localizedDescription)", locale: L10n.locale)
                }
            }
        }
        .alert("导出失败",
               isPresented: Binding(get: { exportError != nil },
                                    set: { if !$0 { exportError = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .overlay(alignment: .bottom) { successToast }
        .animation(.easeInOut(duration: 0.25), value: exportedFiles)
    }

    private var captureHint: some View {
        Group {
            if session.state == .capturing {
                Label("单指在触控板上签名 · 抬起手指结束一笔 · 按 Esc 或点「完成」结束签名", systemImage: "hand.draw")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: session.state == .capturing ? 30 : 0)
        .background(.ultraThinMaterial)
    }

    private var penBar: some View {
        HStack(spacing: 12) {
            PenToolbar()
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if session.state == .capturing {
                Button("完成") { session.commitSession() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!session.canComplete)
            } else {
                Button(session.strokes.isEmpty ? "开始签名" : "继续编辑") { session.beginSession() }
                    .buttonStyle(.borderedProminent)
            }
            Button("撤销") { session.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!session.canUndo)
            Button("清空") { session.clear() }
                .disabled(!session.canClear)
            Spacer()
            Button("导出") { exportCurrent() }
                .disabled(session.strokes.isEmpty)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
    }

    @ViewBuilder
    private var successToast: some View {
        if let urls = exportedFiles {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("已导出到 ~/Desktop/签名/")
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([urls[0]])
                }
                .buttonStyle(.link)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, 56)
        }
    }

    private func exportCurrent() {
        do {
            exportedFiles = try VectorExporter.export(strokes: session.strokes)
            toastDismissTask?.cancel()
            toastDismissTask = Task {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                await MainActor.run { exportedFiles = nil }
            }
        } catch {
            exportError = error.localizedDescription
        }
    }
}
