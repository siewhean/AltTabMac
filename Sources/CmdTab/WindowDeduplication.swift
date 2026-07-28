import Foundation
import CoreGraphics

struct WindowCandidateIdentityKey: Hashable {
    let ownerPID: pid_t
    let windowID: CGWindowID
}

struct WindowCandidateDeduplicationProbe: Equatable {
    let ownerPID: pid_t
    let windowID: CGWindowID
    let title: String
    let bounds: CGRect
    let orderIndex: Int
    let sortScore: CGFloat
    let isOnScreen: Bool
}

enum WindowDeduplication {
    static func deduplicateCandidateProbes(_ candidates: [WindowCandidateDeduplicationProbe]) -> [WindowCandidateDeduplicationProbe] {
        deduplicateCandidates(
            candidates,
            identityKey: { .init(ownerPID: $0.ownerPID, windowID: $0.windowID) },
            prefersReplacement: { lhs, rhs in
                prefersReplacementCandidate(
                    isOnScreen: lhs.isOnScreen,
                    title: lhs.title,
                    bounds: lhs.bounds,
                    sortScore: lhs.sortScore,
                    orderIndex: lhs.orderIndex,
                    overIsOnScreen: rhs.isOnScreen,
                    overTitle: rhs.title,
                    overBounds: rhs.bounds,
                    overSortScore: rhs.sortScore,
                    overOrderIndex: rhs.orderIndex
                )
            }
        )
    }

    static func deduplicateCandidates<T>(
        _ candidates: [T],
        identityKey: (T) -> WindowCandidateIdentityKey,
        prefersReplacement: (T, T) -> Bool
    ) -> [T] {
        var bestByIdentity: [WindowCandidateIdentityKey: T] = [:]

        for candidate in candidates {
            let key = identityKey(candidate)
            if let existing = bestByIdentity[key] {
                if prefersReplacement(candidate, existing) {
                    bestByIdentity[key] = candidate
                }
            } else {
                bestByIdentity[key] = candidate
            }
        }

        return candidates.compactMap { candidate in
            let key = identityKey(candidate)
            return bestByIdentity.removeValue(forKey: key)
        }
    }

    static func prefersReplacementCandidate(
        isOnScreen lhsIsOnScreen: Bool,
        title lhsTitle: String,
        bounds lhsBounds: CGRect,
        sortScore lhsSortScore: CGFloat,
        orderIndex lhsOrderIndex: Int,
        overIsOnScreen rhsIsOnScreen: Bool,
        overTitle rhsTitle: String,
        overBounds rhsBounds: CGRect,
        overSortScore rhsSortScore: CGFloat,
        overOrderIndex rhsOrderIndex: Int
    ) -> Bool {
        if lhsIsOnScreen != rhsIsOnScreen {
            return lhsIsOnScreen
        }

        let lhsHasSpecificTitle = !lhsTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rhsHasSpecificTitle = !rhsTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if lhsHasSpecificTitle != rhsHasSpecificTitle {
            return lhsHasSpecificTitle
        }

        let lhsArea = lhsBounds.width * lhsBounds.height
        let rhsArea = rhsBounds.width * rhsBounds.height
        if lhsArea != rhsArea {
            return lhsArea > rhsArea
        }

        if lhsSortScore != rhsSortScore {
            return lhsSortScore > rhsSortScore
        }

        return lhsOrderIndex < rhsOrderIndex
    }
}
