import SwiftUI
import AppKit

// MARK: - Classic Grid (original Exposé-style thumbnail layout)

/// Horizontal LazyVGrid of window thumbnail cards with the macOS Exposé look.
/// This is the original SwitcherView layout, extracted so SwitcherView.swift
/// can act as a pure style router without mixing layout concerns.
struct ClassicGridView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    private var resolvedSelectedIndex: Int {
        viewModel.resolvedSelectedIndex ?? 0
    }

    var body: some View {
        ZStack {
            // Panel background — vibrancy (liquid glass) or solid dark
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(preferences.enableVibrancy ? 0.45 : 0.0))
                .background(
                    ZStack {
                        if preferences.enableVibrancy {
                            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.06),
                                            Color.white.opacity(0.02),
                                            Color.white.opacity(0.01)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(preferences.enableVibrancy ? 0.12 : 0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 40, x: 0, y: 20)

            VStack(spacing: 0) {
                if viewModel.items.isEmpty {
                    Text("No items")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.50))
                        .frame(width: 300, height: 100)
                } else if ShowcaseRenderingMode.isEnabled {
                    eagerShowcaseGrid
                } else {
                    interactiveGrid
                }
            }
        }
    }

    private var interactiveGrid: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: gridColumns, spacing: viewModel.layout.gridSpacing) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { idx, item in
                        itemCard(item: item, index: idx)
                            .id(idx)
                            .transition(.switcherItemMutation)
                            .onHover { hovering in
                                viewModel.hoveredIndex = hovering ? idx : nil
                            }
                    }
                }
                .animation(.spring(response: 0.24, dampingFraction: 0.84), value: viewModel.items.map(\.id))
                .padding(.horizontal, viewModel.layout.outerPadding)
                .padding(.vertical, viewModel.layout.outerPadding)
            }
            .frame(maxHeight: viewModel.layout.contentHeight)
            .onChange(of: resolvedSelectedIndex) { idx in
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    /// `ImageRenderer` does not instantiate the children of a lazy container when
    /// the view hierarchy never enters a window. The showcase command therefore
    /// uses the same card view in an eager row/column layout. Normal app rendering
    /// continues to use the production LazyVGrid above.
    private var eagerShowcaseGrid: some View {
        let columnCount = max(1, min(viewModel.layout.columns, viewModel.items.count))
        let rowStarts = Array(stride(from: 0, to: viewModel.items.count, by: columnCount))

        return VStack(spacing: viewModel.layout.gridSpacing) {
            ForEach(rowStarts, id: \.self) { rowStart in
                HStack(spacing: viewModel.layout.gridSpacing) {
                    ForEach(rowStart..<min(rowStart + columnCount, viewModel.items.count), id: \.self) { index in
                        itemCard(item: viewModel.items[index], index: index)
                    }
                    if rowStart + columnCount > viewModel.items.count {
                        ForEach(viewModel.items.count..<(rowStart + columnCount), id: \.self) { _ in
                            Color.clear
                                .frame(width: viewModel.layout.cardWidth, height: viewModel.layout.cardHeight)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, viewModel.layout.outerPadding)
        .padding(.vertical, viewModel.layout.outerPadding)
        .frame(
            width: viewModel.layout.contentWidth,
            height: viewModel.layout.contentHeight,
            alignment: .top
        )
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(viewModel.layout.cardWidth),
                spacing: viewModel.layout.gridSpacing
            ),
            count: max(1, viewModel.layout.columns)
        )
    }

    private func itemCard(item: SwitcherItem, index: Int) -> some View {
        ClassicItemCardView(
            item: item,
            isSelected: index == resolvedSelectedIndex,
            mode: viewModel.mode,
            layout: viewModel.layout
        )
    }
}

// MARK: - Individual Item Card

struct ClassicItemCardView: View {
    let item: SwitcherItem
    let isSelected: Bool
    let mode: SwitcherMode
    let layout: SwitcherLayoutMetrics

    var body: some View {
        VStack(spacing: 0) {
            thumbnailView
                .frame(width: layout.cardWidth, height: layout.thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color(red: 0.26, green: 0.58, blue: 1.0).opacity(1.0) : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 3.5 : 0.5
                        )
                )
                .shadow(
                    color: isSelected ? Color(red: 0.19, green: 0.52, blue: 1.0).opacity(0.72) : Color.clear,
                    radius: isSelected ? 42 : 0,
                    x: 0, y: 0
                )
                .shadow(
                    color: isSelected ? Color(red: 0.14, green: 0.40, blue: 1.0).opacity(0.34) : Color.clear,
                    radius: isSelected ? 72 : 0,
                    x: 0, y: 0
                )

            HStack(spacing: 5) {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 20, height: 20)
                }
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.75))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
            .frame(width: layout.cardWidth, alignment: .center)
        }
        .frame(width: layout.cardWidth, height: layout.cardHeight, alignment: .top)
        .contentShape(Rectangle())
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.78), value: isSelected)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.clear)

            if let preview = item.previewImage {
                Image(nsImage: preview)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(preview.size, contentMode: .fit)
                    .frame(width: layout.cardWidth, height: layout.thumbnailHeight)
                    .allowsHitTesting(false)
            } else {
                previewPlaceholder
            }

            // Stronger top-edge fade that covers the title-bar zone.
            LinearGradient(
                colors: [Color.black.opacity(0.65), Color.clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.30)
            )
            .allowsHitTesting(false)
        }
    }

    private var previewPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.025),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 46, height: 10)
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 84, height: 10)
                    Spacer(minLength: 0)
                }

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: max(48, layout.thumbnailHeight * 0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 8)
                    }
                }
            }
            .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
