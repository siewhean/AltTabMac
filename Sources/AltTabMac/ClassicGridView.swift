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
                .fill(Color.white.opacity(preferences.enableVibrancy ? 0.02 : 0.05))
                .background(
                    ZStack {
                        if preferences.enableVibrancy {
                            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                                .opacity(0.76)

                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.08),
                                            Color.white.opacity(0.028),
                                            Color.white.opacity(0.008)
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
                        .stroke(Color.white.opacity(preferences.enableVibrancy ? 0.08 : 0.06), lineWidth: 1)
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
                                    .onHover { hovering in
                                        viewModel.hoveredIndex = hovering ? idx : nil
                                    }
                                }
                            }
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
                            isSelected ? Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.95) : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 2.5 : 0.5
                        )
                )
                .shadow(
                    color: isSelected ? Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.7) : Color.clear,
                    radius: isSelected ? 12 : 0,
                    x: 0, y: 0
                )

            HStack(spacing: 5) {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 16, height: 16)
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
            } else if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: min(96, layout.thumbnailHeight * 0.55),
                           height: min(96, layout.thumbnailHeight * 0.55))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: mode == .tab ? "globe" : "app.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.30))
            }
        }
    }
}
