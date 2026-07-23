import AppKit
import SwiftUI

/// Shared production-only presentation helpers for exact-window state.
/// The legacy views remain unchanged for Phase 1 regression coverage; profile
/// sessions use these variants so minimized/fullscreen/workspace state is never
/// hidden from the user.
struct SwitcherItemStateBadges: View {
    let item: SwitcherItem
    var compact = false

    private var badges: [(String, String, Color)] {
        var values: [(String, String, Color)] = []
        if item.isMinimized {
            values.append(("minus.square.fill", "Minimized", .orange))
        }
        if item.isFullscreen {
            values.append(("arrow.up.left.and.arrow.down.right", "Fullscreen", .blue))
        }
        if let workspace = item.workspaceSnapshot {
            if !workspace.memberships.isEmpty, !workspace.isOnCurrentManagedSpace {
                values.append(("rectangle.stack.fill", "Other Space", .purple))
            }
            if workspace.stageManagerState == .hiddenSet {
                values.append(("rectangle.stack.badge.minus", "Hidden Set", .pink))
            }
        }
        return values
    }

    var body: some View {
        if !badges.isEmpty {
            HStack(spacing: compact ? 3 : 5) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    HStack(spacing: compact ? 0 : 3) {
                        Image(systemName: badge.0)
                            .font(.system(size: compact ? 9 : 10, weight: .bold))
                        if !compact {
                            Text(badge.1)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, compact ? 5 : 7)
                    .padding(.vertical, compact ? 3 : 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(badge.2.opacity(0.86))
                    )
                    .accessibilityLabel(badge.1)
                }
            }
        }
    }
}

private struct WorkspaceCapabilityBanner: View {
    let status: CapabilityStatus

    var body: some View {
        if status.level != .available {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: status.level == .failed
                      ? "exclamationmark.octagon.fill"
                      : "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                    if let reason = status.reason, !reason.isEmpty {
                        Text(reason)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .lineLimit(2)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.orange.opacity(0.65), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 360, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private var title: String {
        switch status.level {
        case .available: return "Exact workspace identity"
        case .degraded: return "Workspace precision is degraded"
        case .unavailable: return "Workspace identity is unavailable"
        case .failed: return "Workspace identity failed"
        }
    }
}

enum ProductionCapabilitySummary {
    static func worstStatus(in items: [SwitcherItem]) -> CapabilityStatus {
        let statuses = items.compactMap(\.workspaceSnapshot?.capability)
        guard !statuses.isEmpty else {
            return .unavailable(
                "Exact workspace metadata is not attached to the current items. CmdTab is using safe visible-window fallback behaviour."
            )
        }

        return statuses.max { severity($0.level) < severity($1.level) } ?? .available
    }

    private static func severity(_ level: CapabilityStatus.Level) -> Int {
        switch level {
        case .available: return 0
        case .degraded: return 1
        case .unavailable: return 2
        case .failed: return 3
        }
    }
}

struct ProductionClassicGridView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    private var selectedIndex: Int { viewModel.resolvedSelectedIndex ?? 0 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(preferences.enableVibrancy ? 0.45 : 0.0))
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(preferences.enableVibrancy ? 0.12 : 0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 40, x: 0, y: 20)

            if viewModel.items.isEmpty {
                Text("No items")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 300, height: 100)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        let columns = Array(
                            repeating: GridItem(
                                .fixed(viewModel.layout.cardWidth),
                                spacing: viewModel.layout.gridSpacing
                            ),
                            count: max(1, viewModel.layout.columns)
                        )
                        LazyVGrid(columns: columns, spacing: viewModel.layout.gridSpacing) {
                            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                                ClassicItemCardView(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    mode: viewModel.mode,
                                    layout: viewModel.layout
                                )
                                .overlay(alignment: .topTrailing) {
                                    SwitcherItemStateBadges(item: item, compact: true)
                                        .padding(7)
                                }
                                .accessibilityValue(accessibilityState(for: item))
                                .id(index)
                                .transition(.switcherItemMutation)
                                .onHover { hovering in
                                    viewModel.hoveredIndex = hovering ? index : nil
                                }
                            }
                        }
                        .animation(
                            .spring(response: 0.24, dampingFraction: 0.84),
                            value: viewModel.items.map(\.id)
                        )
                        .padding(.horizontal, viewModel.layout.outerPadding)
                        .padding(.vertical, viewModel.layout.outerPadding)
                    }
                    .frame(maxHeight: viewModel.layout.contentHeight)
                    .onChange(of: selectedIndex) { index in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
            }

            WorkspaceCapabilityBanner(
                status: ProductionCapabilitySummary.worstStatus(in: viewModel.items)
            )
            .padding(12)
        }
    }

    @ViewBuilder
    private var background: some View {
        if preferences.enableVibrancy {
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.02),
                                Color.white.opacity(0.01),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
        }
    }

    private func accessibilityState(for item: SwitcherItem) -> String {
        var values: [String] = []
        if item.isMinimized { values.append("minimized") }
        if item.isFullscreen { values.append("fullscreen") }
        if let workspace = item.workspaceSnapshot,
           !workspace.memberships.isEmpty,
           !workspace.isOnCurrentManagedSpace {
            values.append("on another Space")
        }
        return values.isEmpty ? "normal window" : values.joined(separator: ", ")
    }
}

struct ProductionCommandPaletteView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    private var selectedIndex: Int { viewModel.resolvedSelectedIndex ?? 0 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .background(
                    Group {
                        if preferences.enableVibrancy {
                            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(preferences.enableVibrancy ? 0.12 : 0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 32, x: 0, y: 16)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.45))
                    Text(viewModel.searchQuery.isEmpty ? "Type to filter…" : viewModel.searchQuery)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(viewModel.searchQuery.isEmpty ? .white.opacity(0.30) : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !viewModel.searchQuery.isEmpty {
                        Text("\(viewModel.items.count) result\(viewModel.items.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(minHeight: 48)

                Divider().overlay(Color.white.opacity(0.10))

                if viewModel.items.isEmpty {
                    Text(viewModel.searchQuery.isEmpty ? "No items" : "No matches")
                        .foregroundStyle(.white.opacity(0.40))
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .padding(.vertical, 8)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                                    ProductionPaletteRow(item: item, isSelected: index == selectedIndex)
                                        .id(index)
                                        .onHover { hovering in
                                            viewModel.hoveredIndex = hovering ? index : nil
                                        }
                                }
                            }
                        }
                        .onChange(of: selectedIndex) { index in
                            withAnimation(.easeInOut(duration: 0.10)) {
                                proxy.scrollTo(index, anchor: .center)
                            }
                        }
                        .onChange(of: viewModel.searchQuery) { _ in
                            proxy.scrollTo(0, anchor: .top)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            WorkspaceCapabilityBanner(
                status: ProductionCapabilitySummary.worstStatus(in: viewModel.items)
            )
            .padding(10)
        }
        .frame(
            width: max(viewModel.layout.contentWidth, 520),
            height: max(viewModel.layout.contentHeight, 120),
            alignment: .top
        )
    }
}

private struct ProductionPaletteRow: View {
    let item: SwitcherItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "app")
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.subtitle.isEmpty ? item.title : item.subtitle)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.88))
                    .lineLimit(1)
                if !item.subtitle.isEmpty, item.title != item.subtitle {
                    Text(item.title)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
            }

            Spacer()
            SwitcherItemStateBadges(item: item)
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color(red: 0.18, green: 0.38, blue: 0.82).opacity(0.30) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? Color(red: 0.26, green: 0.58, blue: 1.0) : .clear,
                            lineWidth: isSelected ? 2.5 : 0
                        )
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ProductionRadialMenuView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    private let canvasSize: CGFloat = 560
    private let ringRadius: CGFloat = 188

    private var visibleSlots: [(slot: Int, index: Int, item: SwitcherItem)] {
        viewModel.radialViewportState.visibleIndices.enumerated().compactMap { slot, index in
            guard viewModel.items.indices.contains(index) else { return nil }
            return (slot, index, viewModel.items[index])
        }
    }

    private var selectedSlot: Int {
        min(
            max(0, viewModel.radialViewportState.selectedSlot),
            max(0, visibleSlots.count - 1)
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.white.opacity(0.03))
                .background(
                    Group {
                        if preferences.enableVibrancy {
                            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                                .clipShape(Circle())
                        } else {
                            Circle().fill(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.90))
                        }
                    }
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 40, x: 0, y: 20)

            centreLabel

            ForEach(visibleSlots, id: \.item.id) { entry in
                let angle = itemAngle(index: entry.slot, total: visibleSlots.count)
                ProductionRadialItem(
                    item: entry.item,
                    isSelected: entry.slot == selectedSlot,
                    angle: angle
                )
                .position(
                    x: canvasSize / 2 + cos(angle) * ringRadius,
                    y: canvasSize / 2 + sin(angle) * ringRadius
                )
                .onHover { hovering in
                    viewModel.hoveredIndex = hovering ? entry.index : nil
                }
            }

            WorkspaceCapabilityBanner(
                status: ProductionCapabilitySummary.worstStatus(in: viewModel.items)
            )
            .padding(18)
        }
        .frame(width: canvasSize, height: canvasSize)
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: visibleSlots.map(\.item.id))
    }

    private var centreLabel: some View {
        VStack(spacing: 5) {
            Image(systemName: viewModel.mode.systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            Text(viewModel.mode.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
            if let index = viewModel.resolvedSelectedIndex,
               viewModel.items.indices.contains(index) {
                let item = viewModel.items[index]
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 190)
                SwitcherItemStateBadges(item: item)
            }
            if viewModel.items.count > RadialMenuViewportState.maxVisible {
                Text("+\(viewModel.items.count - RadialMenuViewportState.maxVisible) more")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
    }

    private func itemAngle(index: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return -.pi / 2 + Double(index) * ((2 * .pi) / Double(total))
    }
}

private struct ProductionRadialItem: View {
    let item: SwitcherItem
    let isSelected: Bool
    let angle: Double

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(
                        isSelected
                            ? Color(red: 0.18, green: 0.38, blue: 0.82).opacity(0.38)
                            : Color.white.opacity(0.08)
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle().strokeBorder(
                            isSelected ? Color(red: 0.26, green: 0.58, blue: 1.0) : .white.opacity(0.14),
                            lineWidth: isSelected ? 3.5 : 1
                        )
                    )
                    .shadow(
                        color: isSelected ? Color(red: 0.19, green: 0.52, blue: 1.0).opacity(0.72) : .clear,
                        radius: isSelected ? 34 : 0
                    )

                Group {
                    if let icon = item.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "app.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: 42, height: 42)
                .position(x: 35, y: 35)

                SwitcherItemStateBadges(item: item, compact: true)
                    .offset(x: 9, y: -8)
            }
            .frame(width: 84, height: 76)
            .scaleEffect(isSelected ? 1.16 : 1.0)

            Text(item.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.60))
                .lineLimit(1)
                .frame(width: 92)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isMinimized ? "minimized" : (item.isFullscreen ? "fullscreen" : "normal window"))
    }
}