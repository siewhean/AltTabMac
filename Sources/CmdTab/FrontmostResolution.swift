import Foundation

struct FrontmostOverrideState: Equatable {
    let identity: SwitcherHistoryIdentity
    let pid: pid_t
    let startedAtUptime: TimeInterval
}

enum FrontmostResolution {
    static let overrideGraceInterval: TimeInterval = 0.18

    static func activeOverride(
        _ overrideState: FrontmostOverrideState?,
        now: TimeInterval,
        graceInterval: TimeInterval = overrideGraceInterval
    ) -> FrontmostOverrideState? {
        guard let overrideState else { return nil }
        return now - overrideState.startedAtUptime <= graceInterval ? overrideState : nil
    }

    static func effectivePID(
        systemFrontmostPID: pid_t,
        observedFrontmostPID: pid_t,
        overrideState: FrontmostOverrideState?,
        now: TimeInterval,
        graceInterval: TimeInterval = overrideGraceInterval
    ) -> pid_t {
        if let overrideState = activeOverride(overrideState, now: now, graceInterval: graceInterval) {
            return overrideState.pid
        }

        if systemFrontmostPID != 0 {
            return systemFrontmostPID
        }

        return observedFrontmostPID
    }

    static func effectiveIdentity(
        availableItems: [SwitcherItem],
        historyEntries: [SwitcherHistoryIdentity],
        systemFrontmostIdentity: SwitcherHistoryIdentity?,
        systemFrontmostPID: pid_t,
        observedFrontmostPID: pid_t,
        overrideState: FrontmostOverrideState?,
        now: TimeInterval,
        graceInterval: TimeInterval = overrideGraceInterval
    ) -> SwitcherHistoryIdentity? {
        if let overrideState = activeOverride(overrideState, now: now, graceInterval: graceInterval),
           availableItems.contains(where: { $0.historyIdentity == overrideState.identity }) {
            return overrideState.identity
        }

        if let systemFrontmostIdentity,
           availableItems.contains(where: { $0.historyIdentity == systemFrontmostIdentity }) {
            return systemFrontmostIdentity
        }

        let pid = effectivePID(
            systemFrontmostPID: systemFrontmostPID,
            observedFrontmostPID: observedFrontmostPID,
            overrideState: overrideState,
            now: now,
            graceInterval: graceInterval
        )
        guard pid != 0 else { return nil }

        let samePIDItems = availableItems.filter { $0.historyIdentity.ownerPID == pid }
        if samePIDItems.count == 1 {
            return samePIDItems[0].historyIdentity
        }

        return availableItems.first(where: {
            $0.kind == .appFallback && $0.historyIdentity.ownerPID == pid
        })?.historyIdentity
    }
}
