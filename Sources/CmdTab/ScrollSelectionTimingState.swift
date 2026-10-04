import AppKit

/// Stamp ingress with the delivery clock; native timestamps can have a
/// different uptime origin or be zero for generated events.
struct ScrollSelectionInput {
    let deltaX: Double
    let deltaY: Double
    let isPrecise: Bool
    let phase: NSEvent.Phase
    let momentumPhase: NSEvent.Phase
    let receivedAt: TimeInterval

    init(event: NSEvent, receivedAt: TimeInterval) {
        deltaX = event.scrollingDeltaX
        deltaY = event.scrollingDeltaY
        isPrecise = event.hasPreciseScrollingDeltas
        phase = event.phase
        momentumPhase = event.momentumPhase
        self.receivedAt = receivedAt
    }
}

/// Turns trackpad packets into deliberate selection steps. Event timestamps are
/// supplied by the caller; delivery time prevents queued packets from replaying
/// several steps together after the UI thread has been busy.
struct ScrollSelectionTimingState {
    private let swipeThreshold: Double = 24
    private let repeatInterval: TimeInterval = 1
    private let phaseLessGestureGap: TimeInterval = 0.25
    private let maximumDeliveryAge: TimeInterval = 0.25
    private var accumulatedDelta: Double = 0
    private var lastStepAt: TimeInterval?
    private var lastPacketAt: TimeInterval?
    private var lastEventAt: TimeInterval?

    mutating func reset() {
        lastEventAt = nil
        resetGesture()
    }

    private mutating func resetGesture() {
        accumulatedDelta = 0
        lastStepAt = nil
        lastPacketAt = nil
    }

    mutating func selectionStep(
        _ input: ScrollSelectionInput,
        deliveredAt: TimeInterval,
        presentationStartedAt: TimeInterval = -.infinity
    ) -> Int? {
        guard input.receivedAt >= presentationStartedAt else { return nil }
        return selectionStep(deltaX: input.deltaX, deltaY: input.deltaY,
                      isPrecise: input.isPrecise, phase: input.phase,
                      momentumPhase: input.momentumPhase,
                      at: input.receivedAt, deliveredAt: deliveredAt)
    }

    mutating func selectionStep(
        deltaX: Double,
        deltaY: Double,
        isPrecise: Bool,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        at timestamp: TimeInterval,
        deliveredAt deliveryTimestamp: TimeInterval? = nil
    ) -> Int? {
        let deliveryTimestamp = deliveryTimestamp ?? timestamp
        guard timestamp.isFinite, deliveryTimestamp.isFinite,
              deliveryTimestamp >= timestamp,
              deliveryTimestamp - timestamp <= maximumDeliveryAge else { return nil }
        if let lastEventAt, timestamp <= lastEventAt { return nil }
        lastEventAt = timestamp
        guard momentumPhase.isEmpty else { return nil }
        if phase.contains(.ended) || phase.contains(.cancelled) {
            resetGesture()
            return nil
        }
        if phase.contains(.began) {
            resetGesture()
        } else if phase.isEmpty, let lastPacketAt,
                  timestamp - lastPacketAt >= phaseLessGestureGap {
            // Some drivers supply precise deltas without gesture phases.
            resetGesture()
        }
        lastPacketAt = timestamp

        let delta = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
        guard delta.isFinite, delta != 0 else { return nil }
        // Keep discrete mouse-wheel detents responsive.
        guard isPrecise else { return delta > 0 ? -1 : 1 }

        if accumulatedDelta * delta < 0 { accumulatedDelta = 0 }
        accumulatedDelta = max(-swipeThreshold, min(swipeThreshold, accumulatedDelta + delta))
        guard abs(accumulatedDelta) >= swipeThreshold else { return nil }
        if let lastStepAt, deliveryTimestamp - lastStepAt < repeatInterval { return nil }
        let step = accumulatedDelta > 0 ? -1 : 1
        accumulatedDelta = 0
        lastStepAt = deliveryTimestamp
        return step
    }
}
