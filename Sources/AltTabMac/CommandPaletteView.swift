import SwiftUI
import AppKit

// MARK: - Command Palette Style

/// Compact vertical list with a live-search header bar.
///
/// How search input works without a key window:
/// The panel is `.nonactivatingPanel` during hotkey-triggered use, so a
/// standard SwiftUI TextField never receives focus. Instead, HotkeyManager
/// intercepts printable keyDown events and forwards them to
/// SwitcherWindowController.appendSearchCharacter(_:) / deleteSearchCharacter().
/// The controller updates `viewModel.searchQuery` and rebuilds `viewModel.items`
/// to only the matching subset, so all existing navigation logic is unchanged.
struct CommandPaletteView: View {
    @ObservedObject var viewModel: SwitcherViewModel
    @ObservedObject private var preferences = SwitcherPreferences.shared

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(preferences.enableVibrancy ? 0.018 : 0.04))
                .background(
                    ZStack {
                        if preferences.enableVibrancy {
                            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                                .opacity(0.78)

                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.07),
                                            Color.white.opacity(0.02),
                                            Color.black.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(preferences.enableVibrancy ? 0.08 : 0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 32, x: 0, y: 16)

            VStack(spacing: 0) {
                searchBar
                Divider().overlay(Color.white.opacity(0.10))
                itemList
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.45))

            // Displays typed characters; acts as a read-only mirror of searchQuery
            // because the panel is nonactivating (see doc comment above).
            Group {
                if viewModel.searchQuery.isEmpty {
                    Text("Type to filter…")
                        .foregroundColor(.white.opacity(0.30))
                } else {
                    Text(viewModel.searchQuery)
                        .foregroundColor(.white)
                }
            }
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)

            if !viewModel.searchQuery.isEmpty {
                Text("\(viewModel.items.count) result\(viewModel.items.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.38))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: Item list

    private var itemList: some View {
        Group {
            if viewModel.items.isEmpty {
                Text(viewModel.searchQuery.isEmpty ? "No items" : "No matches")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white.opacity(0.40))
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .padding(.vertical, 8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { idx, item in
                                PaletteRowView(item: item, isSelected: idx == viewModel.selectedIndex)
                                    .id(idx)
                                    .onHover { hovering in
                                        viewModel.hoveredIndex = hovering ? idx : nil
                                    }
                            }
                        }
                    }
                    .onChange(of: viewModel.selectedIndex) { idx in
                        withAnimation(.easeInOut(duration: 0.10)) {
                            proxy.scrollTo(idx, anchor: .center)
                        }
                    }
                    .onChange(of: viewModel.searchQuery) { _ in
                        // Snap to top whenever the filter changes so the first result is visible.
                        proxy.scrollTo(0, anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - Palette Row

private struct PaletteRowView: View {
    let item: SwitcherItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "app")
                    .frame(width: 22, height: 22)
                    .foregroundColor(.white.opacity(0.35))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.88))
                    .lineLimit(1)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.42))
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(isSelected ? Color(red: 0.18, green: 0.38, blue: 0.82).opacity(0.28) : Color.clear)
        .contentShape(Rectangle())
    }
}
