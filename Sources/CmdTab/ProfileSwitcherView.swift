import SwiftUI

/// Style router whose presentation is frozen by the active shortcut profile.
/// Profile sessions use production variants so minimized/fullscreen/workspace
/// state and degraded capability status remain visible in every style.
struct ProfileSwitcherView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    let style: SwitcherStyle

    var body: some View {
        Group {
            switch style {
            case .classicGrid:
                ProductionClassicGridView(viewModel: viewModel)
            case .commandPalette:
                ProductionCommandPaletteView(viewModel: viewModel)
            case .radialMenu:
                ProductionRadialMenuView(viewModel: viewModel)
            }
        }
        .id(style)
    }
}