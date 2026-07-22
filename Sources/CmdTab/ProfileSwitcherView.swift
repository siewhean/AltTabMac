import SwiftUI

/// Style router whose presentation is frozen by the active shortcut profile.
/// Existing settings-driven callers keep using `SwitcherView`; profile sessions
/// use this router so one profile cannot leak its style into another.
struct ProfileSwitcherView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    let style: SwitcherStyle

    var body: some View {
        Group {
            switch style {
            case .classicGrid:
                ClassicGridView(viewModel: viewModel)
            case .commandPalette:
                CommandPaletteView(viewModel: viewModel)
            case .radialMenu:
                RadialMenuView(viewModel: viewModel)
            }
        }
        .id(style)
    }
}
