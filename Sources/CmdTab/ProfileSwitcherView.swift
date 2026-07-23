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
        .overlay(alignment: .bottomLeading) {
            if !viewModel.items.isEmpty {
                Label("Right-click for window actions", systemImage: "cursorarrow.click.2")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.48))
                    )
                    .padding(12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .id(style)
    }
}