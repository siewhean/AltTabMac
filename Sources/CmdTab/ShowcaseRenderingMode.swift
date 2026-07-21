import Foundation

/// Enables deterministic offscreen layout for the showcase renderer only.
///
/// The production item cards, rows, selection styling, search state, and radial
/// view remain unchanged. Classic Grid and Command Palette replace their lazy
/// containers with eager equivalents during `--render-showcase` because SwiftUI
/// lazy containers do not instantiate offscreen children under ImageRenderer.
enum ShowcaseRenderingMode {
    static var isEnabled: Bool {
        CommandLine.arguments.contains("--render-showcase")
    }
}
