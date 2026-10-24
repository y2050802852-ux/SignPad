import SwiftUI
import SwiftData
import AppKit

/// 历史签名栏：缩略图列表，点击回放重编辑，右键删除。
struct HistorySidebar: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SignatureRecord.createdAt, order: .reverse) private var records: [SignatureRecord]
    @State private var showClearAll = false
    var onReedit: (SignatureRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("历史签名").font(.headline)
                Spacer()
                Button {
                    showClearAll = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(records.isEmpty)
                .help("删除全部历史签名")
                .padding(.trailing, 12)
            }
            .padding(.top, 14)
            .confirmationDialog("删除全部历史签名？", isPresented: $showClearAll, titleVisibility: .visible) {
                Button("全部删除", role: .destructive) {
                    for record in records { modelContext.delete(record) }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("共 \(records.count) 条，此操作不可撤销。")
            }
            if records.isEmpty {
                ContentUnavailableView("暂无签名", systemImage: "signature",
                                       description: Text("完成第一次签名后会显示在这里"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(records) { record in
                            thumbnailCard(record)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func thumbnailCard(_ record: SignatureRecord) -> some View {
        VStack(spacing: 4) {
            if let image = NSImage(data: record.thumbnailPNG) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 190)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary)
                    }
            }
            Text(record.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onTapGesture { onReedit(record) }
        .contextMenu {
            Button("重新编辑") { onReedit(record) }
            Button("删除", role: .destructive) {
                modelContext.delete(record)
            }
        }
    }
}
