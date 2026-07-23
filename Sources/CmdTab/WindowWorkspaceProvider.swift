import AppKit
import CoreGraphics
import Darwin
import Foundation

struct CapabilityStatus: Codable, Equatable, Hashable {
    enum Level: String, Codable {
        case available
        case degraded
        case unavailable
        case failed
    }

    let level: Level
    let reason: String?

    static let available = CapabilityStatus(level: .available, reason: nil)

    static func degraded(_ reason: String) -> CapabilityStatus {
        CapabilityStatus(level: .degraded, reason: reason)
    }

    static func unavailable(_ reason: String) -> CapabilityStatus {
        CapabilityStatus(level: .unavailable, reason: reason)
    }

    static func failed(_ reason: String) -> CapabilityStatus {
        CapabilityStatus(level: .failed, reason: reason)
    }
}

enum WorkspaceKind: String, Codable, Hashable {
    case user
    case fullscreen
    case system
    case unknown
}

enum StageManagerWindowState: String, Codable, Hashable {
    case disabled
    case activeSet
    case hiddenSet
    case offCurrentSpace
    case unknown
}

struct WorkspaceIdentity: Codable, Hashable {
    let spaceID: UInt64
    let displayIdentifier: String?
    let kind: WorkspaceKind

    var stableKey: String {
        "workspace:\(displayIdentifier ?? "unknown-display"):\(spaceID):\(kind.rawValue)"
    }
}

struct WindowWorkspaceSnapshot: Codable, Equatable {
    let memberships: [WorkspaceIdentity]
    let currentSpaceIDs: [UInt64]
    let stageManagerState: StageManagerWindowState
    let capability: CapabilityStatus

    var isOnCurrentManagedSpace: Bool {
        let current = Set(currentSpaceIDs)
        return memberships.contains { current.contains($0.spaceID) }
    }

    var primaryWorkspace: WorkspaceIdentity? {
        memberships.first
    }

    static func fallback(
        isOnScreen: Bool,
        reason: String
    ) -> WindowWorkspaceSnapshot {
        WindowWorkspaceSnapshot(
            memberships: [],
            currentSpaceIDs: [],
            stageManagerState: isOnScreen ? .activeSet : .unknown,
            capability: .degraded(reason)
        )
    }
}

protocol WindowWorkspaceProviding: AnyObject {
    var status: CapabilityStatus { get }
    func refresh()
    func snapshot(
        for windowID: CGWindowID,
        isOnScreen: Bool
    ) -> WindowWorkspaceSnapshot
    func prepareActivation(of workspace: WorkspaceIdentity) -> Bool
}

/// Capability-detected access to macOS managed-space metadata.
///
/// Every call into the private framework is serialized. The production switcher
/// and focused-window history observer both enrich data off-main, so relying only
/// on dictionary locks would still allow concurrent SkyLight calls and racy
/// status reads. Missing or changed symbols always degrade to documented public
/// on-screen behaviour rather than preventing CmdTab from launching.
final class WindowWorkspaceProvider: WindowWorkspaceProviding {
    static let shared = WindowWorkspaceProvider()

    private struct ManagedSpaceMetadata {
        let identity: WorkspaceIdentity
        let isCurrent: Bool
    }

    private struct ResolvedFunctions {
        typealias MainConnection = @convention(c) () -> UInt32
        typealias CopyManagedDisplaySpaces = @convention(c) (
            UInt32
        ) -> Unmanaged<CFArray>?
        typealias CopySpacesForWindows = @convention(c) (
            UInt32,
            UInt32,
            CFArray
        ) -> Unmanaged<CFArray>?
        typealias ManagedDisplaySetCurrentSpace = @convention(c) (
            UInt32,
            CFString,
            UInt64
        ) -> CGError
        typealias SpaceGetType = @convention(c) (
            UInt32,
            UInt64
        ) -> Int32

        let mainConnection: MainConnection
        let copyManagedDisplaySpaces: CopyManagedDisplaySpaces
        let copySpacesForWindows: CopySpacesForWindows
        let setCurrentSpace: ManagedDisplaySetCurrentSpace?
        let spaceGetType: SpaceGetType?
    }

    /// Serializes all SkyLight calls, including a refresh requested by snapshot.
    private let operationLock = NSRecursiveLock()
    /// Protects copied status/cache values for diagnostics and tests.
    private let stateLock = NSLock()
    private let functions: ResolvedFunctions?
    private var _status: CapabilityStatus
    private var cachedBySpaceID: [UInt64: ManagedSpaceMetadata] = [:]
    private var cachedCurrentSpaceIDs = Set<UInt64>()
    private var lastRefresh = Date.distantPast
    private let refreshInterval: TimeInterval = 0.4

    var status: CapabilityStatus {
        stateLock.lock()
        let value = _status
        stateLock.unlock()
        return value
    }

    init() {
        let resolution = Self.resolveFunctions()
        functions = resolution.functions
        _status = resolution.status
        if functions != nil {
            refresh()
        }
    }

    func refresh() {
        operationLock.lock()
        defer { operationLock.unlock() }
        refreshSerialized()
    }

    func snapshot(
        for windowID: CGWindowID,
        isOnScreen: Bool
    ) -> WindowWorkspaceSnapshot {
        operationLock.lock()
        defer { operationLock.unlock() }

        guard let functions else {
            return .fallback(
                isOnScreen: isOnScreen,
                reason: status.reason ??
                    "Exact workspace capability is unavailable."
            )
        }

        refreshIfNeededSerialized()
        let connection = functions.mainConnection()
        let windowNumbers = [NSNumber(value: windowID)] as CFArray
        guard let unmanaged = functions.copySpacesForWindows(
            connection,
            0x7,
            windowNumbers
        ) else {
            return .fallback(
                isOnScreen: isOnScreen,
                reason: "SkyLight could not resolve workspace membership for window \(windowID)."
            )
        }

        let values = unmanaged.takeRetainedValue() as NSArray
        let spaceIDs = values.compactMap { ($0 as? NSNumber)?.uint64Value }

        stateLock.lock()
        let metadata = cachedBySpaceID
        let currentIDs = cachedCurrentSpaceIDs
        let currentStatus = _status
        stateLock.unlock()

        let memberships = spaceIDs.map { spaceID in
            metadata[spaceID]?.identity ?? WorkspaceIdentity(
                spaceID: spaceID,
                displayIdentifier: nil,
                kind: .unknown
            )
        }
        let isCurrent = memberships.contains {
            currentIDs.contains($0.spaceID)
        }
        let stageState = Self.stageManagerState(
            isOnScreen: isOnScreen,
            isOnCurrentSpace: isCurrent
        )

        let capability: CapabilityStatus
        if Self.isStageManagerEnabled(), currentStatus.level == .available {
            capability = .degraded(
                "Space membership is exact. Stage Manager active/hidden-set state is inferred because macOS exposes no supported stable set identifier."
            )
        } else {
            capability = currentStatus
        }

        return WindowWorkspaceSnapshot(
            memberships: memberships,
            currentSpaceIDs: Array(currentIDs).sorted(),
            stageManagerState: stageState,
            capability: capability
        )
    }

    func prepareActivation(of workspace: WorkspaceIdentity) -> Bool {
        operationLock.lock()
        defer { operationLock.unlock() }

        guard let functions,
              let setCurrentSpace = functions.setCurrentSpace,
              let displayIdentifier = workspace.displayIdentifier else {
            return false
        }

        let connection = functions.mainConnection()
        let result = setCurrentSpace(
            connection,
            displayIdentifier as CFString,
            workspace.spaceID
        )
        guard result == .success else {
            updateStatus(
                .failed(
                    "Managed-space activation failed with CGError \(result.rawValue)."
                )
            )
            return false
        }

        refreshSerialized()
        return true
    }

    // MARK: Serialized implementation

    private func refreshSerialized() {
        guard let functions else { return }

        let connection = functions.mainConnection()
        guard let unmanaged = functions.copyManagedDisplaySpaces(connection) else {
            updateStatus(
                .failed("SkyLight returned no managed-display space metadata.")
            )
            return
        }

        let rawArray = unmanaged.takeRetainedValue() as NSArray
        var bySpaceID: [UInt64: ManagedSpaceMetadata] = [:]
        var currentSpaceIDs = Set<UInt64>()

        for case let displayDictionary as NSDictionary in rawArray {
            let displayIdentifier = Self.stringValue(
                in: displayDictionary,
                keys: [
                    "Display Identifier",
                    "DisplayIdentifier",
                    "displayIdentifier",
                ]
            )
            let currentID = Self.currentSpaceID(
                in: displayDictionary
            )
            if let currentID {
                currentSpaceIDs.insert(currentID)
            }

            let rawSpaces = Self.value(
                in: displayDictionary,
                keys: [
                    "Spaces",
                    "spaces",
                    "Managed Spaces",
                    "ManagedSpaces",
                ]
            )
            let spaces = rawSpaces as? NSArray ?? []

            for case let spaceDictionary as NSDictionary in spaces {
                guard let spaceID = Self.spaceID(
                    in: spaceDictionary
                ) else {
                    continue
                }
                let kind = Self.workspaceKind(
                    dictionary: spaceDictionary,
                    connection: connection,
                    functions: functions,
                    spaceID: spaceID
                )
                let identity = WorkspaceIdentity(
                    spaceID: spaceID,
                    displayIdentifier: displayIdentifier,
                    kind: kind
                )
                bySpaceID[spaceID] = ManagedSpaceMetadata(
                    identity: identity,
                    isCurrent: currentID == spaceID
                )
            }

            if let currentID, bySpaceID[currentID] == nil {
                bySpaceID[currentID] = ManagedSpaceMetadata(
                    identity: WorkspaceIdentity(
                        spaceID: currentID,
                        displayIdentifier: displayIdentifier,
                        kind: .unknown
                    ),
                    isCurrent: true
                )
            }
        }

        let newStatus: CapabilityStatus = functions.setCurrentSpace == nil
            ? .degraded(
                "Exact space membership is available, but managed-space activation is unavailable on this macOS build."
            )
            : .available

        stateLock.lock()
        cachedBySpaceID = bySpaceID
        cachedCurrentSpaceIDs = currentSpaceIDs
        lastRefresh = Date()
        _status = newStatus
        stateLock.unlock()
    }

    private func refreshIfNeededSerialized() {
        stateLock.lock()
        let stale = Date().timeIntervalSince(lastRefresh) > refreshInterval
        stateLock.unlock()
        if stale {
            refreshSerialized()
        }
    }

    private func updateStatus(_ status: CapabilityStatus) {
        stateLock.lock()
        _status = status
        stateLock.unlock()
    }

    // MARK: Symbol and metadata parsing

    private static func resolveFunctions() -> (
        functions: ResolvedFunctions?,
        status: CapabilityStatus
    ) {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_LAZY | RTLD_LOCAL
        ) else {
            return (
                nil,
                .unavailable("SkyLight.framework could not be loaded.")
            )
        }

        func symbol(_ names: [String]) -> UnsafeMutableRawPointer? {
            for name in names {
                if let value = dlsym(handle, name) {
                    return value
                }
            }
            return nil
        }

        guard let mainSymbol = symbol([
            "SLSMainConnectionID",
            "CGSMainConnectionID",
        ]),
        let managedSymbol = symbol([
            "SLSCopyManagedDisplaySpaces",
            "CGSCopyManagedDisplaySpaces",
        ]),
        let spacesSymbol = symbol([
            "SLSCopySpacesForWindows",
            "CGSCopySpacesForWindows",
        ]) else {
            return (
                nil,
                .unavailable(
                    "Required SkyLight workspace read symbols are unavailable on this macOS build."
                )
            )
        }

        let setSymbol = symbol([
            "SLSManagedDisplaySetCurrentSpace",
            "CGSManagedDisplaySetCurrentSpace",
        ])
        let typeSymbol = symbol([
            "SLSSpaceGetType",
            "CGSSpaceGetType",
        ])

        let resolved = ResolvedFunctions(
            mainConnection: unsafeBitCast(
                mainSymbol,
                to: ResolvedFunctions.MainConnection.self
            ),
            copyManagedDisplaySpaces: unsafeBitCast(
                managedSymbol,
                to: ResolvedFunctions.CopyManagedDisplaySpaces.self
            ),
            copySpacesForWindows: unsafeBitCast(
                spacesSymbol,
                to: ResolvedFunctions.CopySpacesForWindows.self
            ),
            setCurrentSpace: setSymbol.map {
                unsafeBitCast(
                    $0,
                    to: ResolvedFunctions.ManagedDisplaySetCurrentSpace.self
                )
            },
            spaceGetType: typeSymbol.map {
                unsafeBitCast(
                    $0,
                    to: ResolvedFunctions.SpaceGetType.self
                )
            }
        )

        let status: CapabilityStatus = resolved.setCurrentSpace == nil
            ? .degraded(
                "Managed-space reads are available; direct managed-space activation is unavailable."
            )
            : .available
        return (resolved, status)
    }

    private static func value(
        in dictionary: NSDictionary,
        keys: [String]
    ) -> Any? {
        for key in keys {
            if let value = dictionary[key] {
                return value
            }
        }
        return nil
    }

    private static func stringValue(
        in dictionary: NSDictionary,
        keys: [String]
    ) -> String? {
        value(in: dictionary, keys: keys) as? String
    }

    private static func uint64Value(
        in dictionary: NSDictionary,
        keys: [String]
    ) -> UInt64? {
        if let number = value(in: dictionary, keys: keys) as? NSNumber {
            return number.uint64Value
        }
        if let string = value(in: dictionary, keys: keys) as? String {
            return UInt64(string)
        }
        return nil
    }

    private static func currentSpaceID(
        in displayDictionary: NSDictionary
    ) -> UInt64? {
        guard let current = value(
            in: displayDictionary,
            keys: [
                "Current Space",
                "CurrentSpace",
                "currentSpace",
            ]
        ) else {
            return nil
        }
        if let number = current as? NSNumber {
            return number.uint64Value
        }
        if let dictionary = current as? NSDictionary {
            return spaceID(in: dictionary)
        }
        return nil
    }

    private static func spaceID(
        in dictionary: NSDictionary
    ) -> UInt64? {
        uint64Value(
            in: dictionary,
            keys: [
                "ManagedSpaceID",
                "id64",
                "ID",
                "id",
                "Space ID",
                "spaceID",
            ]
        )
    }

    private static func workspaceKind(
        dictionary: NSDictionary,
        connection: UInt32,
        functions: ResolvedFunctions,
        spaceID: UInt64
    ) -> WorkspaceKind {
        let rawType: Int32?
        if let number = value(
            in: dictionary,
            keys: ["type", "Type"]
        ) as? NSNumber {
            rawType = number.int32Value
        } else if let getter = functions.spaceGetType {
            rawType = getter(connection, spaceID)
        } else {
            rawType = nil
        }

        switch rawType {
        case 0: return .user
        case 4: return .fullscreen
        case 2, 5: return .system
        case .some, .none: return .unknown
        }
    }

    private static func isStageManagerEnabled() -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        let value = CFPreferencesCopyAppValue(
            "GloballyEnabled" as CFString,
            "com.apple.WindowManager" as CFString
        )
        return (value as? NSNumber)?.boolValue ?? false
    }

    private static func stageManagerState(
        isOnScreen: Bool,
        isOnCurrentSpace: Bool
    ) -> StageManagerWindowState {
        guard isStageManagerEnabled() else { return .disabled }
        guard isOnCurrentSpace else { return .offCurrentSpace }
        return isOnScreen ? .activeSet : .hiddenSet
    }
}