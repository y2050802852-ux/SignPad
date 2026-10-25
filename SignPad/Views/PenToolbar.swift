import SwiftUI

/// 笔刷选择 + 颜色选择条（预设色板 + 自定义取色器）。
struct PenToolbar: View {
    @Environment(SigningSession.self) private var session

    var body: some View {
        @Bindable var session = session
        HStack(spacing: 12) {
            Picker("笔刷", selection: $session.currentPen) {
                ForEach(PenKind.allCases) { kind in
                    // rawValue 是持久化键，仅作本地化表的查找键，绝不落库英文
                    Text(LocalizedStringKey(kind.rawValue)).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .labelsHidden()

            ForEach(StrokeColor.palette) { entry in
                Circle()
                    .fill(entry.color.swiftUIColor)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .strokeBorder(session.currentColor == entry.color ? Color.primary : .clear, lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                    .onTapGesture { session.currentColor = entry.color }
                    .help(LocalizedStringKey(entry.name))
            }

            Slider(value: $session.widthScale, in: 0.5...3, step: 0.1)
                .frame(width: 150)
                .help("笔画粗细 0.5×–3×（对新落的笔画生效）")

            ColorPicker("", selection: Binding(
                get: { session.currentColor.swiftUIColor },
                set: { session.currentColor = StrokeColor($0) }
            ))
            .labelsHidden()
        }
    }
}
