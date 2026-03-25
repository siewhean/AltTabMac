import Foundation

struct SwitcherCycleSession {
    let mode: SwitcherMode
    let pinsSnapshot: Bool

    private(set) var items: [SwitcherItem]
    private(set) var selectedIndex: Int
    private(set) var selectedIdentity: SwitcherHistoryIdentity

    init?(
        mode: SwitcherMode,
        items: [SwitcherItem],
        currentFrontmost: SwitcherHistoryIdentity?,
        reverse: Bool,
        pinsSnapshot: Bool
    ) {
        guard !items.isEmpty else { return nil }

        self.mode = mode
        self.pinsSnapshot = pinsSnapshot
        self.items = items
        self.selectedIndex = Self.initialSelectionIndex(
            items: items,
            currentFrontmost: currentFrontmost,
            reverse: reverse
        )
        self.selectedIdentity = items[self.selectedIndex].historyIdentity
    }

    var selectedItem: SwitcherItem {
        items[selectedIndex]
    }

    mutating func advance(reverse: Bool) {
        move(by: reverse ? -1 : 1)
    }

    mutating func move(by delta: Int) {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + items.count) % items.count
        syncSelection()
    }

    mutating func moveUp(columns: Int) {
        guard !items.isEmpty else { return }

        let columnCount = max(1, min(columns, items.count))
        if selectedIndex >= columnCount {
            selectedIndex -= columnCount
        } else {
            var bottom = selectedIndex
            while bottom + columnCount < items.count {
                bottom += columnCount
            }
            selectedIndex = bottom
        }

        syncSelection()
    }

    mutating func moveDown(columns: Int) {
        guard !items.isEmpty else { return }

        let columnCount = max(1, min(columns, items.count))
        if selectedIndex + columnCount < items.count {
            selectedIndex += columnCount
        } else {
            selectedIndex = selectedIndex % columnCount
        }

        syncSelection()
    }

    mutating func refreshItems(_ refreshedItems: [SwitcherItem]) {
        guard !refreshedItems.isEmpty else { return }

        items = refreshedItems
        if let persistedIndex = refreshedItems.firstIndex(where: { $0.historyIdentity == selectedIdentity }) {
            selectedIndex = persistedIndex
        } else {
            selectedIndex = min(selectedIndex, refreshedItems.count - 1)
        }

        syncSelection()
    }

    func commitSelection() -> SwitcherItem {
        selectedItem
    }

    private mutating func syncSelection() {
        guard !items.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex), items.count - 1)
        selectedIdentity = items[selectedIndex].historyIdentity
    }

    private static func initialSelectionIndex(
        items: [SwitcherItem],
        currentFrontmost: SwitcherHistoryIdentity?,
        reverse: Bool
    ) -> Int {
        guard reverse else { return 0 }
        guard items.count > 1 else { return 0 }

        let frontmostWasMovedToEnd = currentFrontmost != nil && items.last?.historyIdentity == currentFrontmost
        if frontmostWasMovedToEnd {
            return max(0, items.count - 2)
        }

        return items.count - 1
    }
}
