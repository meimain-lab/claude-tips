import AppKit
import SwiftUI
import TipsCore

/// Popover content: search field, segments, list or detail, notices and key hints.
struct PopoverView: View {
    @ObservedObject var model: TipsViewModel
    let hotKeyLabel: String

    var body: some View {
        VStack(spacing: 0) {
            SearchField(model: model, hotKeyLabel: hotKeyLabel)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            if let tip = model.detailTip {
                DetailView(model: model, tip: tip)
            } else {
                SegmentBar(model: model)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                TipList(model: model)
                    .padding(.top, 8)
            }
            if !model.library.notices.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(model.library.notices, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
            Divider()
                .padding(.horizontal, 12)
                .padding(.top, 8)
            KeyHints(isDetail: model.detailTip != nil)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 360)
    }
}

private struct SearchField: View {
    @ObservedObject var model: TipsViewModel
    let hotKeyLabel: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜一下：画图、定时、交接", text: $model.query)
                .textFieldStyle(.plain)
                .focused($isFocused)
            Text(hotKeyLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
        )
        .onAppear { isFocused = true }
        .onChange(of: model.focusToken) { _ in isFocused = true }
    }
}

private struct SegmentBar: View {
    @ObservedObject var model: TipsViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var selectedFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color(nsColor: .controlBackgroundColor)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(model.segments, id: \.self) { segment in
                let isSelected = segment == model.segment && !model.isSearching
                Button {
                    model.select(segment: segment)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: segment.symbolName)
                        Text(segment.title)
                        Text("\(model.count(of: segment))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? selectedFill : Color.clear)
                            .shadow(color: .black.opacity(isSelected ? 0.12 : 0), radius: 1, y: 0.5)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
        .opacity(model.isSearching ? 0.5 : 1)
    }
}

/// Row geometry shared by the list frame and the overflow math.
enum TipListMetrics {
    static let rowHeight: Double = 52
    static let spacing: Double = 2
    static let visibleRows = 6
    static let fadeHeight: CGFloat = 28

    static func viewportHeight(rowCount: Int) -> CGFloat {
        CGFloat(min(rowCount, visibleRows)) * CGFloat(rowHeight + spacing)
    }
}

/// Reports the enclosing NSScrollView's vertical offset (0 at the top) whenever
/// it scrolls. SwiftUI geometry preferences do not update on scroll on macOS,
/// so this reads the native scroll view, which stays the source of truth.
private struct ScrollOffsetReader: NSViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
    }

    final class ReaderView: NSView {
        var onChange: ((CGFloat) -> Void)?
        private weak var observedClip: NSClipView?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let scrollView = enclosingScrollView, observedClip !== scrollView.contentView else { return }
            if let observedClip {
                NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: observedClip)
            }
            let clip = scrollView.contentView
            clip.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(boundsChanged), name: NSView.boundsDidChangeNotification, object: clip)
            observedClip = clip
            report()
        }

        @objc private func boundsChanged() { report() }

        private func report() {
            guard let scrollView = enclosingScrollView, let document = scrollView.documentView else { return }
            let visible = scrollView.documentVisibleRect
            let offset = document.isFlipped ? visible.minY : document.bounds.height - visible.maxY
            onChange?(max(0, offset))
        }
    }
}

private struct TipList: View {
    @ObservedObject var model: TipsViewModel
    @State private var offset: CGFloat = 0
    @State private var lastSelected = 0

    var body: some View {
        let rows = model.visibleTips
        Group {
            if rows.isEmpty {
                Text(model.isSearching ? "没有找到，换个词试试" : "这一组还没有条目")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                list(rows)
            }
        }
    }

    private func list(_ rows: [Tip]) -> some View {
        let viewport = TipListMetrics.viewportHeight(rowCount: rows.count)
        let overflow = ListOverflow(
            rowCount: rows.count, rowHeight: TipListMetrics.rowHeight, spacing: TipListMetrics.spacing,
            viewportHeight: Double(viewport), offset: Double(offset)
        )
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: TipListMetrics.spacing) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, tip in
                        TipRow(
                            tip: tip,
                            isSelected: index == model.selectedIndex,
                            isCopied: model.copiedId == tip.id,
                            onCopy: {
                                model.selectedIndex = index
                                model.copy(tip)
                            },
                            onDetail: {
                                model.selectedIndex = index
                                model.detailTip = tip
                            }
                        )
                        .id(tip.id)
                    }
                }
                .padding(.horizontal, 8)
                .background(ScrollOffsetReader { newOffset in
                    // Scrolls can land inside SwiftUI's own update pass, where a
                    // state write would be dropped; apply it on the next turn.
                    DispatchQueue.main.async {
                        if abs(newOffset - offset) > 0.25 { offset = newOffset }
                    }
                })
            }
            .frame(height: viewport)
            .mask(EdgeFadeMask(fadeTop: !overflow.isAtTop, fadeBottom: !overflow.isAtBottom))
            .overlay(alignment: .bottom) {
                if !overflow.isAtBottom, overflow.rowsBelow > 0 {
                    MoreRowsPill(count: overflow.rowsBelow) {
                        guard let first = overflow.firstRowBelow, rows.indices.contains(first) else { return }
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(rows[first].id, anchor: .top) }
                    }
                    .padding(.bottom, 4)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: overflow.isAtBottom)
            .animation(.easeOut(duration: 0.15), value: overflow.isAtTop)
            .onChange(of: model.selectedIndex) { index in
                // Keep one row of lookahead in the moving direction, so the
                // selected row never sits under the edge fade or the hint.
                let previous = lastSelected
                lastSelected = index
                guard rows.indices.contains(index) else { return }
                let target = index > previous ? min(index + 1, rows.count - 1) : max(index - 1, 0)
                proxy.scrollTo(rows[target].id)
            }
            .onChange(of: rows.map(\.id)) { ids in
                if let first = ids.first { proxy.scrollTo(first, anchor: .top) }
            }
            .onChange(of: model.focusToken) { _ in
                if let first = rows.first { proxy.scrollTo(first.id, anchor: .top) }
            }
        }
    }
}

/// Opaque in the middle; fades the top or bottom edge only where more rows are hidden.
private struct EdgeFadeMask: View {
    let fadeTop: Bool
    let fadeBottom: Bool

    var body: some View {
        VStack(spacing: 0) {
            edge(fading: fadeTop, from: .clear, to: .black)
            Rectangle().fill(Color.black)
            edge(fading: fadeBottom, from: .black, to: .clear)
        }
    }

    private func edge(fading: Bool, from: Color, to: Color) -> some View {
        ZStack {
            LinearGradient(colors: [from, to], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(Color.black).opacity(fading ? 0 : 1)
        }
        .frame(height: TipListMetrics.fadeHeight)
    }
}

/// Neutral hint at the bottom of an overflowing list; a click pages down.
private struct MoreRowsPill: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("还有 \(count) 条")
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.regularMaterial)
                    .overlay(Capsule().stroke(Color.primary.opacity(0.12)))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("向下翻一页")
    }
}

/// The tip's own SF Symbol when it exists, else its group's.
func symbolName(for tip: Tip) -> String {
    if !tip.icon.isEmpty, NSImage(systemSymbolName: tip.icon, accessibilityDescription: nil) != nil {
        return tip.icon
    }
    return tip.isUnsorted ? "tray" : tip.group.symbolName
}

private struct TipRow: View {
    let tip: Tip
    let isSelected: Bool
    let isCopied: Bool
    let onCopy: () -> Void
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName(for: tip))
                .font(.system(size: 14))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color.white.opacity(0.22) : Color.primary.opacity(0.07))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .lineLimit(1)
                Text(tip.copy)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 4)
            if isCopied {
                Text("已复制").font(.callout)
            } else if tip.isMissing {
                Text("已不存在").font(.caption)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            } else if isSelected {
                Text("↵ 复制").font(.callout)
            }
            Button(action: onDetail) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 18, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.white.opacity(0.85)) : AnyShapeStyle(.tertiary))
            .help("详情")
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
        .opacity(tip.isMissing && !isSelected ? 0.5 : 1)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
    }
}

private struct DetailView: View {
    @ObservedObject var model: TipsViewModel
    let tip: Tip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                model.detailTip = nil
            } label: {
                Label("返回", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: symbolName(for: tip))
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.07)))
                Text(tip.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if tip.isMissing {
                    Spacer()
                    Text("已不存在").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !tip.detail.isEmpty {
                Text(tip.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(tip.copy)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
            HStack {
                Spacer()
                Button {
                    model.copy(tip)
                } label: {
                    Text(model.copiedId == tip.id ? "已复制" : "复制")
                        .frame(minWidth: 64)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

private struct KeyHints: View {
    let isDetail: Bool

    var body: some View {
        HStack(spacing: 0) {
            if isDetail {
                hint(["←"], "返回")
                Spacer()
                hint(["↵"], "复制")
            } else {
                hint(["↑", "↓"], "选择")
                Spacer()
                hint(["↵"], "复制")
                Spacer()
                hint(["→"], "详情")
            }
            Spacer()
            hint(["esc"], "关闭")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func hint(_ keys: [String], _ label: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.primary.opacity(0.2))
                    )
            }
            Text(label)
        }
    }
}
