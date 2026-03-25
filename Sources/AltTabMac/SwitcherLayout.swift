import AppKit

struct SwitcherLayoutMetrics {
    let columns: Int
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let thumbnailHeight: CGFloat
    let gridSpacing: CGFloat
    let outerPadding: CGFloat
    let contentWidth: CGFloat
    let contentHeight: CGFloat

    static let empty = SwitcherLayoutMetrics(
        columns: 1,
        cardWidth: 300,
        cardHeight: 215,
        thumbnailHeight: 187,
        gridSpacing: 12,
        outerPadding: 18,
        contentWidth: 336,
        contentHeight: 251
    )

    static func make(itemCount: Int, visibleFrame: CGRect) -> SwitcherLayoutMetrics {
        guard itemCount > 0 else { return .empty }

        let outerPadding: CGFloat = 18
        let gridSpacing: CGFloat = 12
        let labelHeight: CGFloat = 28

        // Use most of the screen so thumbnails are large and readable.
        let maxPanelWidth  = min(1600, visibleFrame.width  * 0.90)
        let maxPanelHeight = min(900,  visibleFrame.height * 0.82)

        // Hard cap: 4 columns. Keeps cards wide enough to see real content.
        let maxColumns = min(4, itemCount)

        var chosenColumns = 1
        var chosenCardWidth: CGFloat = 300

        // Walk from maxColumns down; prefer cards ≥ 260pt wide.
        for columns in stride(from: maxColumns, through: 1, by: -1) {
            let available = maxPanelWidth - outerPadding * 2 - CGFloat(columns - 1) * gridSpacing
            let candidate = floor(available / CGFloat(columns))
            if candidate >= 260 || columns == 1 {
                chosenColumns = columns
                chosenCardWidth = min(420, candidate)
                break
            }
        }

        let rows = Int(ceil(Double(itemCount) / Double(chosenColumns)))

        // 16:10 thumbnail aspect ratio.
        let thumbnailHeight = floor(chosenCardWidth * 0.625)
        let cardHeight      = thumbnailHeight + labelHeight

        // Do NOT scale cards down to fit. Keep them big; let ScrollView handle
        // overflow. The panel height is capped so extra rows scroll.
        let fullGridHeight = CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * gridSpacing
        let contentHeight  = min(maxPanelHeight, outerPadding * 2 + fullGridHeight)

        let contentWidth = min(
            maxPanelWidth,
            outerPadding * 2
                + CGFloat(chosenColumns) * chosenCardWidth
                + CGFloat(max(0, chosenColumns - 1)) * gridSpacing
        )

        return SwitcherLayoutMetrics(
            columns: chosenColumns,
            cardWidth: chosenCardWidth,
            cardHeight: cardHeight,
            thumbnailHeight: max(100, thumbnailHeight),
            gridSpacing: gridSpacing,
            outerPadding: outerPadding,
            contentWidth: contentWidth,
            contentHeight: contentHeight
        )
    }

    // MARK: - Command Palette layout

    /// Narrow, tall panel for the vertical search list.
    /// Row height is fixed at 44pt; the panel grows with item count up to 60% of
    /// screen height, then the list scrolls.
    static func makePalette(itemCount: Int, visibleFrame: CGRect) -> SwitcherLayoutMetrics {
        guard itemCount > 0 else { return .empty }
        let panelWidth: CGFloat  = 520
        let rowHeight: CGFloat   = 44
        let searchBarHeight: CGFloat = 48
        let maxPanelHeight = min(visibleFrame.height * 0.60, 520)
        let rawHeight = searchBarHeight + CGFloat(itemCount) * rowHeight
        let contentHeight = max(120, min(maxPanelHeight, rawHeight))

        return SwitcherLayoutMetrics(
            columns: 1,
            cardWidth: panelWidth - 32,
            cardHeight: rowHeight,
            thumbnailHeight: rowHeight,
            gridSpacing: 0,
            outerPadding: 0,
            contentWidth: panelWidth,
            contentHeight: contentHeight
        )
    }

    // MARK: - Radial Menu layout

    /// Fixed square canvas for the circular icon arrangement.
    /// The panel is 560×560pt, centred on the cursor at show time.
    static func makeRadial(itemCount: Int) -> SwitcherLayoutMetrics {
        return SwitcherLayoutMetrics(
            columns: 1,
            cardWidth: 60,
            cardHeight: 90,
            thumbnailHeight: 60,
            gridSpacing: 0,
            outerPadding: 0,
            contentWidth: 560,
            contentHeight: 560
        )
    }
}
