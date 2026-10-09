import AppKit
import CoreGraphics
for (cgPhase, expected): (Int64, NSEvent.Phase) in [(1, .began), (2, .changed), (4, .ended), (8, .cancelled), (128, .mayBegin)] {
 let cg = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: -30, wheel2: 3, wheel3: 0)!
 cg.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
 cg.setIntegerValueField(.scrollWheelEventScrollPhase, value: cgPhase)
 let ns = NSEvent(cgEvent: cg)!
 precondition(ns.phase == expected, "phase mapping")
 precondition(ns.hasPreciseScrollingDeltas, "precision mapping")
 precondition(ns.scrollingDeltaY == -30, "delta mapping")
 precondition(abs(ns.timestamp - Double(cg.timestamp) / 1e9) < 0.000001, "timestamp mapping")
}
for (cgMomentum, expected): (Int64, NSEvent.Phase) in [(1, .began), (2, .changed), (3, .ended)] {
 let cg = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -30, wheel2: 0, wheel3: 0)!
 cg.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
 cg.setIntegerValueField(.scrollWheelEventMomentumPhase, value: cgMomentum)
 precondition(NSEvent(cgEvent: cg)!.momentumPhase == expected, "momentum mapping")
}
print("PASS synthetic CGEvent/NSEvent adapter: 5 gesture phases, 3 momentum phases, precise delta and timestamp preservation")
