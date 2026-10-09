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

