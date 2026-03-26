import AppKit
import CoreGraphics

/// Enumerates browser tabs via AppleScript, returning SwitcherItems that activate the chosen tab.
final class TabSwitcher {
    private let cacheQueue = DispatchQueue(label: "AltTabMac.TabSwitcher.Cache", qos: .userInitiated)
    private let history = SwitcherHistoryStore.shared
    private let preferences = SwitcherPreferences.shared
    private var cachedItems: [SwitcherItem] = []
    private var lastRefresh = Date.distantPast
    private var isRefreshing = false
    private let refreshInterval: TimeInterval = 2.0
    private var currentActiveTabIdentity: SwitcherHistoryIdentity?

    var onItemsChanged: (([SwitcherItem]) -> Void)?

    /// Ordered list of supported browsers (bundle ID → display name).
    private let browsers: [(id: String, name: String)] = [
        ("com.google.Chrome", "Google Chrome"),
        ("company.thebrowser.Browser", "Arc"),
        ("com.apple.Safari", "Safari"),
        ("org.mozilla.firefox", "Firefox"),
        ("com.microsoft.edgemac", "Microsoft Edge"),
        ("com.brave.Browser", "Brave Browser"),
    ]

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier,
                  let browser = self.browser(for: bundleID) else {
                return
            }

            if let activeDescriptor = self.currentActiveTabDescriptor(bundleID: browser.id, name: browser.name) {
                self.currentActiveTabIdentity = activeDescriptor.historyIdentity
                self.history.noteActivation(activeDescriptor.historyIdentity)
            }

            self.warmCache(force: true)
        }

        NotificationCenter.default.addObserver(
            forName: SwitcherPreferences.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.warmCache(force: true)
        }

        warmCache(force: true)
    }

    func getItems() -> [SwitcherItem] {
        warmCache()
        return cacheQueue.sync { cachedItems }
    }

    func warmCache(force: Bool = false) {
        cacheQueue.async { [weak self] in
            self?.refreshCacheIfNeeded(force: force)
        }
    }

    func currentFrontmostIdentity() -> SwitcherHistoryIdentity? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              let browser = browser(for: bundleID) else {
            return nil
        }

        if let descriptor = currentActiveTabDescriptor(bundleID: bundleID, name: browser.name) {
            currentActiveTabIdentity = descriptor.historyIdentity
            return descriptor.historyIdentity
        }

        return currentActiveTabIdentity
    }

    // MARK: - Private

    private func refreshCacheIfNeeded(force: Bool) {
        guard force || Date().timeIntervalSince(lastRefresh) > refreshInterval else { return }
        guard !isRefreshing else { return }
        isRefreshing = true

        let items = buildItems()
        cachedItems = items
        lastRefresh = Date()
        isRefreshing = false

        DispatchQueue.main.async { [weak self] in
            self?.onItemsChanged?(items)
        }
    }

    private func buildItems() -> [SwitcherItem] {
        let running = NSWorkspace.shared.runningApplications

        // Skip the CGWindowListCopyWindowInfo call inside browserPreviewLookup()
        // entirely when no supported browser is running — avoids a full system
        // window enumeration on every cache refresh for non-browser users.
        let runningBundleIDs = Set(running.compactMap(\.bundleIdentifier))
        guard browsers.contains(where: { runningBundleIDs.contains($0.id) }) else { return [] }

        let previewLookup = browserPreviewLookup()
        var items: [SwitcherItem] = []

        for browser in browsers {
            guard running.contains(where: { $0.bundleIdentifier == browser.id }) else { continue }
            let browserIcon = running.first(where: { $0.bundleIdentifier == browser.id })?.icon
            guard let descriptors = fetchTabs(bundleID: browser.id, name: browser.name, previewLookup: previewLookup[browser.id] ?? [], icon: browserIcon) else {
                continue
            }

            items.append(contentsOf: descriptors.map { descriptor in
                SwitcherItem(
                    title: descriptor.title,
                    subtitle: descriptor.url,
                    icon: descriptor.icon,
                    previewImage: descriptor.preview,
                    historyIdentity: descriptor.historyIdentity,
                    sourceAppIdentifier: descriptor.bundleID,
                    kind: .browserTab
                ) { [weak self] in
                    self?.activateTab(descriptor)
                }
            })
        }

        // Sort by MRU before applying the user-defined cap so the limit always
        // retains the most recently accessed tabs rather than an arbitrary slice.
        let historySnapshot = history.snapshot()
        items.sort { lhs, rhs in
            let lhsRank = historySnapshot.firstIndex(of: lhs.historyIdentity) ?? Int.max
            let rhsRank = historySnapshot.firstIndex(of: rhs.historyIdentity) ?? Int.max
            return lhsRank < rhsRank
        }

        let limit = preferences.maxBrowserTabsShown
        if limit > 0 { items = Array(items.prefix(limit)) }

        return items
    }

    private func fetchTabs(bundleID: String, name: String, previewLookup: [NSImage?], icon: NSImage?) -> [BrowserTabDescriptor]? {
        let script: String

        switch bundleID {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                set tabList to {}
                set winIdx to 0
                repeat with w in windows
                    set winIdx to winIdx + 1
                    set tabIdx to 0
                    repeat with t in tabs of w
                        set tabIdx to tabIdx + 1
                        set end of tabList to {winIdx, tabIdx, name of t, URL of t}
                    end repeat
                end repeat
                return tabList
            end tell
            """
        case "org.mozilla.firefox":
            return nil
        default:
            script = """
            tell application "\(name)"
                set tabList to {}
                set winIdx to 0
                repeat with w in windows
                    set winIdx to winIdx + 1
                    set tabIdx to 0
                    repeat with t in tabs of w
                        set tabIdx to tabIdx + 1
                        set end of tabList to {winIdx, tabIdx, title of t, URL of t}
                    end repeat
                end repeat
                return tabList
            end tell
            """
        }

        guard let result = executeAppleScript(script) else { return nil }
        let count = result.numberOfItems
        guard count > 0 else { return [] }

        var descriptors: [BrowserTabDescriptor] = []
        for index in 1...count {
            guard let record = result.atIndex(index),
                  record.numberOfItems >= 4 else {
                continue
            }

            let winIdx = Int(record.atIndex(1)?.int32Value ?? 0)
            let tabIdx = Int(record.atIndex(2)?.int32Value ?? 0)
            let title = record.atIndex(3)?.stringValue ?? "Untitled"
            let url = record.atIndex(4)?.stringValue ?? ""
            let preview = (previewLookup.indices.contains(winIdx - 1) ? previewLookup[winIdx - 1] : nil)
                ?? makeFallbackPreview(title: title, subtitle: url, icon: icon)

            descriptors.append(
                BrowserTabDescriptor(
                    bundleID: bundleID,
                    browserName: name,
                    windowIndex: max(1, winIdx),
                    tabIndex: max(1, tabIdx),
                    title: title,
                    url: url,
                    icon: icon,
                    preview: preview
                )
            )
        }

        return descriptors
    }

    private func currentActiveTabDescriptor(bundleID: String, name: String) -> BrowserTabDescriptor? {
        let script: String
        if bundleID == "com.apple.Safari" {
            script = """
            tell application "Safari"
                if (count of windows) is 0 then
                    return {}
                end if
                set frontTab to current tab of front window
                return {1, (index of frontTab), (name of frontTab), (URL of frontTab)}
            end tell
            """
        } else if bundleID == "org.mozilla.firefox" {
            return nil
        } else {
            script = """
            tell application "\(name)"
                if (count of windows) is 0 then
                    return {}
                end if
                return {1, (active tab index of front window), (title of active tab of front window), (URL of active tab of front window)}
            end tell
            """
        }

        guard let result = executeAppleScript(script),
              result.numberOfItems >= 4 else {
            return nil
        }

        let icon = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID })?.icon
        return BrowserTabDescriptor(
            bundleID: bundleID,
            browserName: name,
            windowIndex: max(1, Int(result.atIndex(1)?.int32Value ?? 1)),
            tabIndex: max(1, Int(result.atIndex(2)?.int32Value ?? 1)),
            title: result.atIndex(3)?.stringValue ?? "Untitled",
            url: result.atIndex(4)?.stringValue ?? "",
            icon: icon,
            preview: nil
        )
    }

    private func activateTab(_ descriptor: BrowserTabDescriptor) {
        let didActivate: Bool
        if descriptor.bundleID == "com.apple.Safari" {
            didActivate = activateSafariTab(descriptor)
        } else {
            didActivate = activateChromiumTab(descriptor)
        }

        guard didActivate else { return }
        currentActiveTabIdentity = descriptor.historyIdentity
        history.noteActivation(descriptor.historyIdentity)
        warmCache(force: true)
    }

    private func activateChromiumTab(_ descriptor: BrowserTabDescriptor) -> Bool {
        let script = """
        on safeWindowIndex(requestedIndex, windowCount)
            if windowCount <= 0 then
                return 0
            end if
            if requestedIndex < 1 then
                return 1
            end if
            if requestedIndex > windowCount then
                return windowCount
            end if
            return requestedIndex
        end safeWindowIndex

        on safeTabIndex(requestedIndex, tabCount)
            if tabCount <= 0 then
                return 0
            end if
            if requestedIndex < 1 then
                return 1
            end if
            if requestedIndex > tabCount then
                return tabCount
            end if
            return requestedIndex
        end safeTabIndex

        tell application "\(descriptor.browserName)"
            set targetURL to \(appleScriptStringLiteral(descriptor.url))
            set targetTitle to \(appleScriptStringLiteral(descriptor.title))
            set fallbackWindowIndex to \(descriptor.windowIndex)
            set fallbackTabIndex to \(descriptor.tabIndex)

            set windowCount to count of windows
            if windowCount is 0 then
                return {}
            end if

            set resolvedWin to 0
            set resolvedTab to 0
            repeat with winIdx from 1 to windowCount
                set tabCount to count of tabs of window winIdx
                repeat with tabIdx from 1 to tabCount
                    set currentTab to tab tabIdx of window winIdx
                    set currentURL to ""
                    set currentTitle to ""
                    try
                        set currentURL to URL of currentTab
                    end try
                    try
                        set currentTitle to title of currentTab
                    end try

                    if resolvedWin is 0 and targetURL is not "" and currentURL is targetURL then
                        if targetTitle is "" or currentTitle is targetTitle then
                            set resolvedWin to winIdx
                            set resolvedTab to tabIdx
                        end if
                    end if

                    if resolvedWin is 0 and targetURL is "" and targetTitle is not "" and currentTitle is targetTitle then
                        set resolvedWin to winIdx
                        set resolvedTab to tabIdx
                    end if
                end repeat
            end repeat

            if resolvedWin is 0 then
                set resolvedWin to my safeWindowIndex(fallbackWindowIndex, windowCount)
                set fallbackTabCount to count of tabs of window resolvedWin
                set resolvedTab to my safeTabIndex(fallbackTabIndex, fallbackTabCount)
            end if

            if resolvedWin is 0 or resolvedTab is 0 then
                return {}
            end if

            activate
            set active tab index of window resolvedWin to resolvedTab
            set index of window resolvedWin to 1
            return {resolvedWin, resolvedTab}
        end tell
        """

        guard let result = executeAppleScript(script) else { return false }
        return result.numberOfItems >= 2
    }

    private func activateSafariTab(_ descriptor: BrowserTabDescriptor) -> Bool {
        let script = """
        on safeWindowIndex(requestedIndex, windowCount)
            if windowCount <= 0 then
                return 0
            end if
            if requestedIndex < 1 then
                return 1
            end if
            if requestedIndex > windowCount then
                return windowCount
            end if
            return requestedIndex
        end safeWindowIndex

        on safeTabIndex(requestedIndex, tabCount)
            if tabCount <= 0 then
                return 0
            end if
            if requestedIndex < 1 then
                return 1
            end if
            if requestedIndex > tabCount then
                return tabCount
            end if
            return requestedIndex
        end safeTabIndex

        tell application "Safari"
            set targetURL to \(appleScriptStringLiteral(descriptor.url))
            set targetTitle to \(appleScriptStringLiteral(descriptor.title))
            set fallbackWindowIndex to \(descriptor.windowIndex)
            set fallbackTabIndex to \(descriptor.tabIndex)

            set windowCount to count of windows
            if windowCount is 0 then
                return {}
            end if

            set resolvedWin to 0
            set resolvedTab to 0
            repeat with winIdx from 1 to windowCount
                set tabCount to count of tabs of window winIdx
                repeat with tabIdx from 1 to tabCount
                    set currentTab to tab tabIdx of window winIdx
                    set currentURL to ""
                    set currentTitle to ""
                    try
                        set currentURL to URL of currentTab
                    end try
                    try
                        set currentTitle to name of currentTab
                    end try

                    if resolvedWin is 0 and targetURL is not "" and currentURL is targetURL then
                        if targetTitle is "" or currentTitle is targetTitle then
                            set resolvedWin to winIdx
                            set resolvedTab to tabIdx
                        end if
                    end if

                    if resolvedWin is 0 and targetURL is "" and targetTitle is not "" and currentTitle is targetTitle then
                        set resolvedWin to winIdx
                        set resolvedTab to tabIdx
                    end if
                end repeat
            end repeat

            if resolvedWin is 0 then
                set resolvedWin to my safeWindowIndex(fallbackWindowIndex, windowCount)
                set fallbackTabCount to count of tabs of window resolvedWin
                set resolvedTab to my safeTabIndex(fallbackTabIndex, fallbackTabCount)
            end if

            if resolvedWin is 0 or resolvedTab is 0 then
                return {}
            end if

            activate
            set current tab of window resolvedWin to tab resolvedTab of window resolvedWin
            set index of window resolvedWin to 1
            return {resolvedWin, resolvedTab}
        end tell
        """

        guard let result = executeAppleScript(script) else { return false }
        return result.numberOfItems >= 2
    }

    private func browserPreviewLookup() -> [String: [NSImage?]] {
        let windowInfos = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var lookup: [String: [NSImage?]] = [:]

        for browser in browsers {
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == browser.id }) else { continue }
            let previews = windowInfos.enumerated()
                .compactMap { index, info -> (Int, CGWindowID, CGRect)? in
                    guard let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                          ownerPID == app.processIdentifier,
                          let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                          layer == 0,
                          let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue,
                          alpha > 0.08,
                          let sharingState = (info[kCGWindowSharingState as String] as? NSNumber)?.intValue,
                          sharingState != 0,
                          let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                          let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                          let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                          bounds.width >= 120,
                          bounds.height >= 80 else {
                        return nil
                    }

                    return (index, windowID, bounds)
                }
                .sorted { $0.0 < $1.0 }
                .map { capturePreview(windowID: $0.1, bounds: $0.2) }

            lookup[browser.id] = previews
        }

        return lookup
    }

    private func capturePreview(windowID: CGWindowID, bounds: CGRect) -> NSImage? {
        let imageOptions: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]

        if let cgImage = CGWindowListCreateImage(bounds, .optionIncludingWindow, windowID, imageOptions),
           cgImage.width >= 80, cgImage.height >= 60 {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }

        if let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, imageOptions),
           cgImage.width >= 80, cgImage.height >= 60 {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }

        return nil
    }

    private func makeFallbackPreview(title: String, subtitle: String, icon: NSImage?) -> NSImage? {
        let size = NSSize(width: 640, height: 400)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0).setFill()
        NSRect(origin: .zero, size: size).fill()

        let headerRect = NSRect(x: 0, y: size.height - 54, width: size.width, height: 54)
        NSColor(calibratedRed: 0.17, green: 0.19, blue: 0.23, alpha: 1.0).setFill()
        headerRect.fill()

        if let icon {
            icon.draw(in: NSRect(x: 34, y: size.height / 2 - 64, width: 128, height: 128))
        }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 25, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.48)
        ]

        NSString(string: title).draw(
            at: NSPoint(x: 190, y: size.height / 2 + 10),
            withAttributes: titleAttributes
        )

        let subtitleText = subtitle.isEmpty ? "Browser tab" : subtitle
        NSString(string: subtitleText).draw(
            at: NSPoint(x: 190, y: size.height / 2 - 26),
            withAttributes: subtitleAttributes
        )

        return image
    }

    private func executeAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        guard let appleScript = NSAppleScript(source: source) else { return nil }
        var errorInfo: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorInfo)
        if errorInfo != nil {
            return nil
        }
        return result
    }

    private func browser(for bundleID: String) -> (id: String, name: String)? {
        browsers.first(where: { $0.id == bundleID })
    }

    private func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

private struct BrowserTabDescriptor {
    let bundleID: String
    let browserName: String
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
    let icon: NSImage?
    let preview: NSImage?

    var historyIdentity: SwitcherHistoryIdentity {
        .browserTab(bundleID: bundleID, url: url, title: title)
    }
}
