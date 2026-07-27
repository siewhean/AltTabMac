import AppKit
import Foundation

private enum FixtureScenario: String {
    case standard
    case minimized
    case duplicateTitles = "duplicate-titles"
    case fullscreen
    case floatingPanel = "floating-panel"
    case delayedFocus = "delayed-focus"
    case unresponsive
}

private final class FixtureDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windows: [NSWindow] = []
    private var floatingPanel: NSPanel?
    private let scenario: FixtureScenario

    init(scenario: FixtureScenario) {
        self.scenario = scenario
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        createStandardWindows()
        applyScenario()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func createStandardWindows() {
        let visible = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = CGSize(width: min(620, visible.width * 0.45), height: min(440, visible.height * 0.55))

        for index in 0..<3 {
            let title = scenario == .duplicateTitles && index < 2
                ? "WindowLab — Duplicate"
                : "WindowLab — A\(index + 1)"
            let xStep = scenario == .duplicateTitles && index < 2 ? 24 : 54
            let yStep = scenario == .duplicateTitles && index < 2 ? 24 : 44
            let origin = CGPoint(
                x: visible.minX + 80 + CGFloat(index * xStep),
                y: visible.maxY - size.height - 80 - CGFloat(index * yStep)
            )
            let window = NSWindow(
                contentRect: CGRect(origin: origin, size: size),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            let intendedFrame = window.frame
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("WindowLab.A\(index + 1)")
            window.title = title
            if scenario == .duplicateTitles && index < 2 {
                // Deliberately omit document identity for the same-title pair.
                // Their 24-point stagger keeps rounded bounds within the
                // durable matcher's ambiguity margin.
                window.representedURL = nil
            } else {
                window.representedURL = URL(
                    fileURLWithPath: "/tmp/WindowLab-A\(index + 1).txt"
                )
            }
            window.delegate = self
            window.contentViewController = NSHostinglessFixtureViewController(
                title: title,
                detail: "Exact fixture window \(index + 1) · PID \(ProcessInfo.processInfo.processIdentifier)"
            )
            // AppKit may otherwise restore a previous scenario's minimized state
            // or resize to the controller's fitting size. The fixture must start
            // from the same observable state on every launch.
            window.setFrame(intendedFrame, display: false)
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
    }

    private func applyScenario() {
        switch scenario {
        case .standard, .duplicateTitles:
            break

        case .minimized:
            windows.dropFirst().first?.miniaturize(nil)

        case .fullscreen:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.windows.last?.toggleFullScreen(nil)
            }

        case .floatingPanel:
            let panel = NSPanel(
                contentRect: CGRect(x: 160, y: 160, width: 360, height: 180),
                styleMask: [.titled, .utilityWindow, .closable],
                backing: .buffered,
                defer: false
            )
            let intendedFrame = panel.frame
            panel.isRestorable = false
            panel.title = "WindowLab — Floating Utility"
            panel.identifier = NSUserInterfaceItemIdentifier("WindowLab.Utility")
            panel.contentViewController = NSHostinglessFixtureViewController(
                title: "Floating Utility",
                detail: "This panel must not become a default top-level switcher target."
            )
            panel.setFrame(intendedFrame, display: false)
            panel.isFloatingPanel = true
            panel.orderFront(nil)
            floatingPanel = panel

        case .delayedFocus:
            windows.forEach { $0.preventsApplicationTerminationWhenModal = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.windows.first?.makeKeyAndOrderFront(nil)
            }

        case .unresponsive:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                Thread.sleep(forTimeInterval: 30)
            }
        }
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "WindowLab")
        appItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "New Window",
            action: #selector(newWindow),
            keyEquivalent: "n"
        ).target = self
        appMenu.addItem(
            withTitle: "Minimize Second Window",
            action: #selector(minimizeSecond),
            keyEquivalent: "m"
        ).target = self
        appMenu.addItem(
            withTitle: "Restore All Windows",
            action: #selector(restoreAll),
            keyEquivalent: "r"
        ).target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit WindowLab",
            action: #selector(terminate),
            keyEquivalent: "q"
        ).target = self
        NSApp.mainMenu = mainMenu
    }

    @objc private func newWindow() {
        let index = windows.count + 1
        let window = NSWindow(
            contentRect: CGRect(x: 240 + index * 16, y: 220 + index * 14, width: 560, height: 380),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let intendedFrame = window.frame
        window.isRestorable = false
        window.identifier = NSUserInterfaceItemIdentifier("WindowLab.A\(index)")
        window.title = "WindowLab — A\(index)"
        window.representedURL = URL(fileURLWithPath: "/tmp/WindowLab-A\(index).txt")
        window.delegate = self
        window.contentViewController = NSHostinglessFixtureViewController(
            title: window.title,
            detail: "Dynamically created exact fixture window."
        )
        window.setFrame(intendedFrame, display: false)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }

    @objc private func minimizeSecond() {
        guard windows.indices.contains(1) else { return }
        windows[1].miniaturize(nil)
    }

    @objc private func restoreAll() {
        for window in windows {
            window.deminiaturize(nil)
            window.orderFront(nil)
        }
    }

    @objc private func terminate() {
        NSApp.terminate(nil)
    }
}

private final class NSHostinglessFixtureViewController: NSViewController {
    private let heading: String
    private let detail: String

    init(title: String, detail: String) {
        heading = title
        self.detail = detail
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: heading)
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setAccessibilityLabel("Fixture window title: \(heading)")

        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 14)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        let identifierLabel = NSTextField(labelWithString: "Accessibility and CGWindow identity test fixture")
        identifierLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        identifierLabel.textColor = .tertiaryLabelColor
        identifierLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(titleLabel)
        root.addSubview(detailLabel)
        root.addSubview(identifierLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -28),
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 28),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            identifierLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            identifierLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -28),
        ])
        view = root
    }
}

let argument = CommandLine.arguments.dropFirst().first ?? FixtureScenario.standard.rawValue
private let scenario = FixtureScenario(rawValue: argument) ?? .standard
let application = NSApplication.shared
private let delegate = FixtureDelegate(scenario: scenario)
application.delegate = delegate
application.run()
