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

private struct TipList: View {
    @ObservedObject var model: TipsViewModel

    var body: some View {
        let rows = model.visibleTips
        Group {
            if rows.isEmpty {
                Text(model.isSearching ? "没有找到，换个词试试" : "这一组还没有条目")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
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
                    }
                    .frame(height: min(CGFloat(rows.count) * 54, 54 * 6))
                    .onChange(of: model.selectedIndex) { index in
                        guard rows.indices.contains(index) else { return }
                        proxy.scrollTo(rows[index].id)
                    }
                }
            }
        }
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
