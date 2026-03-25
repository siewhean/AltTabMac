import Foundation

enum HotkeyTriggerModifier: Equatable {
    case command
    case option
}

struct HotkeyPendingInvocation: Equatable {
    let generation: Int
    let mode: SwitcherMode
    let reverse: Bool
    let modifier: HotkeyTriggerModifier
}

enum HotkeyTriggerPhase: Equatable {
    case idle
    case armed(HotkeyPendingInvocation)
    case visible(HotkeyPendingInvocation)
    case cancelled(HotkeyPendingInvocation)
    case committed(HotkeyPendingInvocation)

    var invocation: HotkeyPendingInvocation? {
        switch self {
        case .idle:
            return nil
        case let .armed(invocation),
             let .visible(invocation),
             let .cancelled(invocation),
             let .committed(invocation):
            return invocation
        }
    }
}

enum HotkeyTriggerReleaseAction: Equatable {
    case none
    case abort(HotkeyPendingInvocation)
    case commit(HotkeyPendingInvocation)
}

struct HotkeyTriggerStateMachine {
    private(set) var phase: HotkeyTriggerPhase = .idle

    var currentInvocation: HotkeyPendingInvocation? {
        phase.invocation
    }

    var activeModifier: HotkeyTriggerModifier? {
        currentInvocation?.modifier
    }

    var hasActiveTrigger: Bool {
        switch phase {
        case .armed, .visible:
            return true
        default:
            return false
        }
    }

    mutating func arm(_ invocation: HotkeyPendingInvocation) {
        phase = .armed(invocation)
    }

    mutating func updateInvocation(_ invocation: HotkeyPendingInvocation) {
        switch phase {
        case .armed:
            phase = .armed(invocation)
        case .visible:
            phase = .visible(invocation)
        default:
            phase = .armed(invocation)
        }
    }

    mutating func revealIfArmed(generation: Int, modifier: HotkeyTriggerModifier) -> HotkeyPendingInvocation? {
        guard case let .armed(invocation) = phase,
              invocation.generation == generation,
              invocation.modifier == modifier else {
            return nil
        }

        phase = .visible(invocation)
        return invocation
    }

    mutating func handleModifierRelease(_ modifier: HotkeyTriggerModifier) -> HotkeyTriggerReleaseAction {
        switch phase {
        case let .armed(invocation) where invocation.modifier == modifier:
            phase = .cancelled(invocation)
            return .abort(invocation)
        case let .visible(invocation) where invocation.modifier == modifier:
            phase = .committed(invocation)
            return .commit(invocation)
        default:
            return .none
        }
    }

    mutating func cancel() -> HotkeyPendingInvocation? {
        switch phase {
        case let .armed(invocation), let .visible(invocation):
            phase = .cancelled(invocation)
            return invocation
        default:
            return nil
        }
    }

    mutating func markCommittedExternally() -> HotkeyPendingInvocation? {
        switch phase {
        case let .armed(invocation), let .visible(invocation):
            phase = .committed(invocation)
            return invocation
        default:
            return nil
        }
    }

    mutating func reset() {
        phase = .idle
    }
}
