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

    mutating func replaceItems(_ refreshedItems: [SwitcherItem], selectedIndex: Int = 0) {
        guard !refreshedItems.isEmpty else { return }
        items = refreshedItems
        self.selectedIndex = min(max(0, selectedIndex), refreshedItems.count - 1)
        syncSelection()
    }

    mutating func selectIndex(_ index: Int) {
        guard !items.isEmpty else { return }
        selectedIndex = min(max(0, index), items.count - 1)
        syncSelection()
    }

    mutating func removeItem(withID id: String) -> Bool {
        guard let removalIndex = items.firstIndex(where: { $0.id == id }) else { return false }
        items.remove(at: removalIndex)

        guard !items.isEmpty else {
            selectedIndex = 0
            return true
        }

        if removalIndex < selectedIndex {
            selectedIndex -= 1
        } else if selectedIndex >= items.count {
            selectedIndex = items.count - 1
        }

        syncSelection()
        return true
    }

    mutating func removeItems(where shouldRemove: (SwitcherItem) -> Bool) -> Bool {
        let remainingItems = items.filter { !shouldRemove($0) }
        guard remainingItems.count != items.count else { return false }
        guard !remainingItems.isEmpty else {
            items = []
            selectedIndex = 0
            return true
        }

        let previousSelectionID = items[selectedIndex].id
        items = remainingItems
        if let persistedIndex = remainingItems.firstIndex(where: { $0.id == previousSelectionID }) {
            selectedIndex = persistedIndex
        } else {
            selectedIndex = min(selectedIndex, remainingItems.count - 1)
        }

        syncSelection()
        return true
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
        guard items.count > 1 else { return 0 }

        // SwitcherOrdering normally moves the current exact identity to the end.
        // Keep a second fail-safe here because a stale or provisional snapshot may
        // briefly arrive in a different order. A quick trigger must never commit
        // the already-focused exact window when another target is available.
        let proposed: Int
        if reverse,
           let currentFrontmost,
           let currentIndex = items.firstIndex(where: {
               $0.historyIdentity == currentFrontmost
           }) {
            proposed = (currentIndex - 1 + items.count) % items.count
        } else {
            proposed = reverse ? items.count - 1 : 0
        }

        guard let currentFrontmost,
              items[proposed].historyIdentity == currentFrontmost else {
            return proposed
        }
        return (proposed + (reverse ? -1 : 1) + items.count) % items.count
    }
}
