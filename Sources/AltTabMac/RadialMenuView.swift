import SwiftUI
import AppKit

// MARK: - Radial Menu Style

/// Circular arrangement of app icons around the centre of the panel.
/// The panel itself is centred on the cursor at show time (see SwitcherWindowController).
///
/// Up to maxVisible items are shown; items beyond that are hidden.
/// Arrow keys cycle around the ring: left/right advance one step,
/// up/down jump half-way across the circle.
struct RadialMenuView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    private static let maxVisible = 8
    private let canvasSize: CGFloat = 560
    private let ringRadius: CGFloat = 188

    private var visibleItems: [SwitcherItem] {
        Array(viewModel.items.prefix(Self.maxVisible))
    }

    var body: some View {
        ZStack {
            // Subtle circular frosted panel so the background shows through
            Circle()
                .fill(Color.white.opacity(preferences.enableVibrancy ? 0.015 : 0.03))
                .background(
                    ZStack {
                        if preferences.enableVibrancy {
                            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                                .clipShape(Circle())
                                .opacity(0.72)

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.06),
                                            Color.white.opacity(0.02),
                                            Color.black.opacity(0.06)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            Circle()
                                .fill(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.90))
                        }
                    }
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(preferences.enableVibrancy ? 0.075 : 0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 40, x: 0, y: 20)

            // Centre label
            VStack(spacing: 5) {
                Image(systemName: viewModel.mode.systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Text(viewModel.mode.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.38))
                if viewModel.items.count > Self.maxVisible {
                    Text("+\(viewModel.items.count - Self.maxVisible) more")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.28))
                }
            }

            // Ring items
            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { idx, item in
                let angle = itemAngle(index: idx, total: visibleItems.count)
                let isSelected = idx == viewModel.selectedIndex
                let centre = canvasSize / 2

                RadialItemView(item: item, isSelected: isSelected)
                    .position(
                        x: centre + cos(angle) * ringRadius,
                        y: centre + sin(angle) * ringRadius
                    )
                    .onHover { hovering in
                        viewModel.hoveredIndex = hovering ? idx : nil
                    }
            }
        }
        .frame(width: canvasSize, height: canvasSize)
    }

    /// Distribute items evenly around the ring, starting at the top (12 o'clock).
    private func itemAngle(index: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        let step = (2 * .pi) / Double(total)
        return -.pi / 2 + Double(index) * step
    }
}

// MARK: - Radial Item Node

private struct RadialItemView: View {
    let item: SwitcherItem
    let isSelected: Bool

    private let circleSize: CGFloat = 62

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(isSelected
                          ? Color(red: 0.18, green: 0.38, blue: 0.82).opacity(0.38)
                          : Color.white.opacity(0.08))
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected
                                    ? Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.90)
                                    : Color.white.opacity(0.14),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.55) : .clear,
                        radius: 14, x: 0, y: 0
                    )

                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.40))
                }
            }
            .scaleEffect(isSelected ? 1.12 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: isSelected)

            Text(item.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.60))
                .lineLimit(1)
                .frame(width: 84, alignment: .center)
        }
    }
}
