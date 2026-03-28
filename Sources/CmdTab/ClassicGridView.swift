import SwiftUI
import AppKit

// MARK: - Classic Grid (original Exposé-style thumbnail layout)

/// Horizontal LazyVGrid of window thumbnail cards with the macOS Exposé look.
/// This is the original SwitcherView layout, extracted so SwitcherView.swift
/// can act as a pure style router without mixing layout concerns.
struct ClassicGridView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

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
                                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { idx, item in
                                    ClassicItemCardView(
                                        item: item,
                                        isSelected: idx == viewModel.selectedIndex,
                                        mode: viewModel.mode,
                                        layout: viewModel.layout
                                    )
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
                        .onChange(of: viewModel.selectedIndex) { idx in
                            withAnimation(.easeInOut(duration: 0.12)) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
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
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.78), value: isSelected)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(isSelected ? 0.35 : 0.50))

            if let preview = item.previewImage {
                Image(nsImage: preview)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
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
