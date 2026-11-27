import CoreGraphics
import Foundation

/// Pure gesture state machine for the battle arena (no UIKit, unit-testable).
///
/// Rules (first-round tuning values):
///  * A drag commits as soon as it crosses `swipeThreshold` (30 pt); the dominant axis
///    picks the action (←/→ evade, ↑ dash in, ↓ step back). One action per touch.
///  * A touch held ≥ `chargeDelay` (0.22 s) that has moved < `chargeSlop` (22 pt) becomes a
///    charge and stays a charge until it ends.
///  * On lift, an uncommitted touch gets a final displacement check (fast flicks that never
///    produced a move event); only a true tap (< threshold, not charging) yields a basic attack.
///  * A committed touch never produces anything else, even if its action was rejected
///    (e.g. not enough evade gauge) — no basic attack on lift.
struct ArenaGesture {
    enum Action: Equatable {
        case evade(lateral: Float)   // +1 right, -1 left
        case dash
        case stepBack
        case basic
        case chargeStart
        case chargeEnd
    }

    static let swipeThreshold: CGFloat = 30
    static let chargeSlop: CGFloat = 22
    static let chargeDelay: Double = 0.22

    private struct Track {
        let start: CGPoint
        let time: Double
        var committed = false
        var charging = false
    }

    private var tracks: [Int: Track] = [:]

    var activeCount: Int { tracks.count }
    var isCharging: Bool { tracks.values.contains { $0.charging } }

    mutating func began(id: Int, at p: CGPoint, time: Double) {
        tracks[id] = Track(start: p, time: time)
    }

    private static func swipe(_ dx: CGFloat, _ dy: CGFloat) -> Action {
        if abs(dx) >= abs(dy) { return .evade(lateral: dx > 0 ? 1 : -1) }
        return dy < 0 ? .dash : .stepBack
    }

    /// Returns an action the moment the drag crosses the threshold (at most once per touch).
    mutating func moved(id: Int, to p: CGPoint) -> Action? {
        guard var t = tracks[id], !t.committed, !t.charging else { return nil }
        let dx = p.x - t.start.x, dy = p.y - t.start.y
        guard hypot(dx, dy) >= ArenaGesture.swipeThreshold else { return nil }
        t.committed = true
        tracks[id] = t
        return ArenaGesture.swipe(dx, dy)
    }

    /// Polled every frame: promotes a still touch to a charge.
    mutating func tick(time: Double, location: (Int) -> CGPoint?) -> Action? {
        guard !isCharging else { return nil }
        for (id, t) in tracks where !t.committed && !t.charging {
            guard time - t.time >= ArenaGesture.chargeDelay, let p = location(id) else { continue }
            if hypot(p.x - t.start.x, p.y - t.start.y) < ArenaGesture.chargeSlop {
                var u = t
                u.charging = true
                tracks[id] = u
                return .chargeStart
            }
        }
        return nil
    }

    mutating func ended(id: Int, at p: CGPoint) -> Action? {
        guard let t = tracks.removeValue(forKey: id) else { return nil }
        if t.charging { return .chargeEnd }
        if t.committed { return nil }
        let dx = p.x - t.start.x, dy = p.y - t.start.y
        if hypot(dx, dy) >= ArenaGesture.swipeThreshold { return ArenaGesture.swipe(dx, dy) }
        return .basic
    }

    /// System cancel: end silently (stop charging if needed, never fire an attack).
    mutating func cancelled(id: Int) -> Action? {
        guard let t = tracks.removeValue(forKey: id) else { return nil }
        return t.charging ? .chargeEnd : nil
    }

    /// Pause / AUTO / screen change: forget every touch. Only new touches can start gestures.
    mutating func reset() {
        tracks.removeAll()
    }
}
