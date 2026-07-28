import SwiftUI
import AppKit

struct RadialMenuViewportState {
    static let maxVisible = 8
    static let replacementThreshold = 4

    var visibleIndices: [Int] = []
    var selectedSlot: Int = 0
    var lastDirection: Int = 0
    var consecutiveMoves: Int = 0
    var nextRightIndex: Int?
    var nextLeftIndex: Int?

    mutating func reset(itemCount: Int, selectedIndex: Int) {
        let visibleCount = min(Self.maxVisible, max(0, itemCount))
        visibleIndices = Array(0..<visibleCount)
        selectedSlot = visibleCount == 0 ? 0 : min(max(0, selectedIndex), visibleCount - 1)
        lastDirection = 0
        consecutiveMoves = 0
        nextRightIndex = itemCount > visibleCount ? visibleCount % itemCount : nil
        nextLeftIndex = itemCount > visibleCount ? itemCount - 1 : nil
    }

    mutating func advance(direction: Int, itemCount: Int) -> Int {
        guard itemCount > 0 else {
            reset(itemCount: 0, selectedIndex: 0)
            return 0
        }

        let visibleCount = min(Self.maxVisible, itemCount)
        if visibleIndices.count != visibleCount || visibleIndices.contains(where: { $0 < 0 || $0 >= itemCount }) {
            reset(itemCount: itemCount, selectedIndex: min(selectedSlot, visibleCount - 1))
        }

        let stepDirection = direction >= 0 ? 1 : -1
        for _ in 0..<max(1, abs(direction)) {
            advanceOne(direction: stepDirection, itemCount: itemCount)
        }
        return visibleIndices[selectedSlot]
    }

    private mutating func advanceOne(direction: Int, itemCount: Int) {
        let visibleCount = visibleIndices.count
        guard visibleCount > 0 else { return }

        selectedSlot = (selectedSlot + direction + visibleCount) % visibleCount

        if lastDirection == direction {
            consecutiveMoves += 1
        } else {
            lastDirection = direction
            consecutiveMoves = 1
        }

        guard itemCount > visibleCount, consecutiveMoves >= Self.replacementThreshold else { return }

        let replacementSlot = (selectedSlot + (visibleCount / 2)) % visibleCount
        if direction > 0 {
            if let next = takeNextRight(itemCount: itemCount) {
                visibleIndices[replacementSlot] = next
            }
        } else {
            if let next = takeNextLeft(itemCount: itemCount) {
                visibleIndices[replacementSlot] = next
            }
        }
    }

    private mutating func takeNextRight(itemCount: Int) -> Int? {
        guard itemCount > visibleIndices.count, let start = nextRightIndex else { return nil }

        var candidate = start
        for _ in 0..<itemCount {
            if !visibleIndices.contains(candidate) {
                nextRightIndex = (candidate + 1) % itemCount
                return candidate
            }
            candidate = (candidate + 1) % itemCount
        }

        return nil
    }

    private mutating func takeNextLeft(itemCount: Int) -> Int? {
        guard itemCount > visibleIndices.count, let start = nextLeftIndex else { return nil }

        var candidate = start
        for _ in 0..<itemCount {
            if !visibleIndices.contains(candidate) {
                nextLeftIndex = (candidate - 1 + itemCount) % itemCount
                return candidate
            }
            candidate = (candidate - 1 + itemCount) % itemCount
        }

        return nil
    }
}

// MARK: - Radial Menu Style

/// Circular arrangement of app icons around the centre of the panel.
/// The panel itself is centred on the cursor at show time (see SwitcherWindowController).
struct RadialMenuView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    private let canvasSize: CGFloat = 560
    private let ringRadius: CGFloat = 188

    private var visibleSlots: [(slot: Int, absoluteIndex: Int, item: SwitcherItem)] {
        viewModel.radialViewportState.visibleIndices.enumerated().compactMap { slot, absoluteIndex in
            guard absoluteIndex >= 0, absoluteIndex < viewModel.items.count else { return nil }
            return (slot, absoluteIndex, viewModel.items[absoluteIndex])
        }
    }

    private var selectedItem: SwitcherItem? {
        guard let resolvedSelectedIndex = viewModel.resolvedSelectedIndex else { return nil }
        return viewModel.items[resolvedSelectedIndex]
    }

    private var localSelectedIndex: Int {
        min(max(0, viewModel.radialViewportState.selectedSlot), max(0, visibleSlots.count - 1))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .background(
                    Group {
                        if preferences.enableVibrancy {
                            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                                .clipShape(Circle())
                        } else {
                            Color.clear
                        }
                    }
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 40, x: 0, y: 20)

            VStack(spacing: 5) {
                Image(systemName: viewModel.mode.systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Text(viewModel.mode.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.38))
                if let selectedItem {
                    Text(selectedItem.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: 190)
                    if !selectedItem.subtitle.isEmpty {
                        Text(selectedItem.subtitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.48))
                            .lineLimit(1)
                            .frame(maxWidth: 190)
                    }
                }
                if viewModel.items.count > RadialMenuViewportState.maxVisible {
                    Text("+\(viewModel.items.count - RadialMenuViewportState.maxVisible) more")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.28))
                }
            }

            ForEach(visibleSlots, id: \.item.id) { slot in
                let angle = itemAngle(index: slot.slot, total: visibleSlots.count)
                let isSelected = slot.slot == localSelectedIndex
                let centre = canvasSize / 2

                RadialItemView(item: slot.item, isSelected: isSelected, angle: angle)
                    .transition(.switcherItemMutation)
                    .position(
                        x: centre + cos(angle) * ringRadius,
                        y: centre + sin(angle) * ringRadius
                    )
                    .onHover { hovering in
                        viewModel.hoveredIndex = hovering ? slot.absoluteIndex : nil
                    }
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: visibleSlots.map(\.item.id))
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: localSelectedIndex)
    }

    private func itemAngle(index: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        let step = (2 * .pi) / Double(total)
        return -.pi / 2 + Double(index) * step
    }
}

private struct RadialItemView: View {
    let item: SwitcherItem
    let isSelected: Bool
    let angle: Double

    private let circleSize: CGFloat = 70

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if isSelected {
                    Circle()
                        .stroke(Color(red: 0.25, green: 0.57, blue: 1.0).opacity(0.75), lineWidth: 2)
                        .frame(width: circleSize + 22, height: circleSize + 22)
                        .overlay(
                            Circle()
                                .fill(Color(red: 0.19, green: 0.52, blue: 1.0).opacity(0.12))
                        )
                        .blur(radius: 0.3)
                }

                Circle()
                    .fill(isSelected
                          ? Color(red: 0.18, green: 0.38, blue: 0.82).opacity(0.38)
                          : Color.white.opacity(0.08))
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected
                                    ? Color(red: 0.26, green: 0.58, blue: 1.0).opacity(1.0)
                                    : Color.white.opacity(0.14),
                                lineWidth: isSelected ? 3.5 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? Color(red: 0.19, green: 0.52, blue: 1.0).opacity(0.72) : .clear,
                        radius: isSelected ? 34 : 0, x: 0, y: 0
                    )
                    .shadow(
                        color: isSelected ? Color(red: 0.14, green: 0.40, blue: 1.0).opacity(0.30) : .clear,
                        radius: isSelected ? 60 : 0, x: 0, y: 0
                    )

                if isSelected {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.74, green: 0.86, blue: 1.0))
                        .rotationEffect(.degrees(angle * 180 / .pi + 180))
                        .offset(y: -(circleSize / 2 + 12))
                }

                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 38, height: 38)
                        .clipped()
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.40))
                }
            }
            .scaleEffect(isSelected ? 1.18 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: isSelected)

            Text(item.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.60))
                .lineLimit(1)
                .frame(width: 84, alignment: .center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.subtitle)")
        .accessibilityHint(isSelected ? "Currently selected window" : "Select to switch to window")
    }
}
