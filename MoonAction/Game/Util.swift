import UIKit
import simd
import CoreHaptics

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    func blend(_ other: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1)
    }

    func lighter(_ t: CGFloat = 0.3) -> UIColor { blend(.white, t) }
    func darker(_ t: CGFloat = 0.3) -> UIColor { blend(.black, t) }

    static let maRed = UIColor(hex: 0xE5483A)
    static let maPurple = UIColor(hex: 0x8D5CF6)
    static let maGold = UIColor(hex: 0xF5B83D)
    static let maBlue = UIColor(hex: 0x3B8BF6)
    static let maTeal = UIColor(hex: 0x23A3B8)
    static let maCoin = UIColor(hex: 0xFFD45A)
    static let maGreen = UIColor(hex: 0x4CD964)
}

extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(hi, Swift.max(lo, self)) }
}

extension Float {
    func clamped(_ lo: Float, _ hi: Float) -> Float { Swift.min(hi, Swift.max(lo, self)) }
}

extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { Swift.min(hi, Swift.max(lo, self)) }
}

func chance(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }

func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }

func easeOut(_ t: Float) -> Float { 1 - (1 - t) * (1 - t) }

/// All vibration goes through here so it can be turned off in settings.
@MainActor
enum Haptics {
    private static let key = "moonaction.haptics"
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Impact generator that respects the setting.
    @MainActor
    final class Gen {
        private let g: UIImpactFeedbackGenerator
        init(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { g = UIImpactFeedbackGenerator(style: style) }
        func impactOccurred() { if Haptics.enabled { g.impactOccurred() } }
        func impactOccurred(intensity: CGFloat) { if Haptics.enabled { g.impactOccurred(intensity: intensity) } }
        func prepare() { if Haptics.enabled { g.prepare() } }
    }

    static let light = Gen(.light)
    static let medium = Gen(.medium)
    static let heavy = Gen(.heavy)
    static let rigid = Gen(.rigid)

    static func hit(_ big: Bool) { (big ? heavy : light).impactOccurred() }

    /// Layered CoreHaptics: sharp transient + short body rumble (heavier hits rumble longer / lower).
    static func impact(heavy big: Bool, crit: Bool = false) {
        guard enabled else { return }
        if !Rich.shared.impact(heavy: big, crit: crit) { hit(big) }
    }

    /// Ki charge: continuous low rumble that builds while held.
    static func charge(_ on: Bool) {
        guard enabled || !on else { return }
        Rich.shared.charge(on)
    }

    /// CoreHaptics wrapper; on devices without haptics (simulator, iPad) every call is a graceful no-op.
    @MainActor
    final class Rich {
        static let shared = Rich()
        private var engine: CHHapticEngine?
        private var chargePlayer: CHHapticAdvancedPatternPlayer?
        private var chargeStart = Date()

        private init() {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
            engine = try? CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in try? self?.engine?.start() }
            }
            try? engine?.start()
        }

        @discardableResult
        func impact(heavy: Bool, crit: Bool) -> Bool {
            guard let engine else { return false }
            let sharp = CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: heavy || crit ? 1 : 0.6),
                .init(parameterID: .hapticSharpness, value: crit ? 1 : 0.7),
            ], relativeTime: 0)
            let body = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: heavy ? 0.8 : 0.35),
                .init(parameterID: .hapticSharpness, value: heavy ? 0.15 : 0.35),
            ], relativeTime: 0.01, duration: heavy ? 0.16 : 0.05)
            do {
                try engine.start()
                let pattern = try CHHapticPattern(events: [sharp, body], parameters: [])
                try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
                return true
            } catch {
                return false
            }
        }

        func charge(_ on: Bool) {
            guard let engine else { return }
            if !on {
                try? chargePlayer?.stop(atTime: CHHapticTimeImmediate)
                chargePlayer = nil
                return
            }
            guard chargePlayer == nil else { return }
            let rumble = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: 1),
                .init(parameterID: .hapticSharpness, value: 0.1),
            ], relativeTime: 0, duration: 30)
            // Intensity ramps from soft to strong over 1.2 s (crescendo), then holds.
            let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0.15), .init(relativeTime: 1.2, value: 0.75), .init(relativeTime: 30, value: 0.75),
            ], relativeTime: 0)
            do {
                try engine.start()
                let pattern = try CHHapticPattern(events: [rumble], parameterCurves: [curve])
                let player = try engine.makeAdvancedPlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                chargePlayer = player
            } catch {
                chargePlayer = nil
            }
        }
    }
    static func select() { if enabled { UISelectionFeedbackGenerator().selectionChanged() } }
    static func success() { if enabled { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
}

/// Main-thread scheduler driven by game time (pauses with the game).
@MainActor
final class Timeline {
    private struct Item {
        let time: Double
        let order: Int
        let tag: ObjectIdentifier?
        let fn: () -> Void
    }

    private var items: [Item] = []
    private var counter = 0
    private(set) var now: Double = 0

    func cancelAll() { items.removeAll() }

    func after(_ delay: Double, tag: AnyObject? = nil, _ fn: @escaping () -> Void) {
        counter += 1
        items.append(Item(time: now + max(0, delay), order: counter, tag: tag.map { ObjectIdentifier($0) }, fn: fn))
    }

    /// Schedule a list of (delay-from-previous, action) steps.
    func sequence(tag: AnyObject?, _ steps: [(Double, () -> Void)]) {
        var t = 0.0
        for (d, fn) in steps {
            t += d
            after(t, tag: tag, fn)
        }
    }

    func cancel(tag: AnyObject) {
        let id = ObjectIdentifier(tag)
        items.removeAll { $0.tag == id }
    }

    func has(tag: AnyObject) -> Bool {
        let id = ObjectIdentifier(tag)
        return items.contains { $0.tag == id }
    }

    func tick(_ dt: Double) {
        now += dt
        while true {
            guard let idx = items.indices.filter({ items[$0].time <= now })
                .min(by: { (items[$0].time, items[$0].order) < (items[$1].time, items[$1].order) }) else { break }
            let item = items.remove(at: idx)
            item.fn()
        }
    }
}

/// Runs `fn` on the main actor after `seconds` of real time.
@MainActor
func realDelay(_ seconds: Double, _ fn: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        fn()
    }
}

/// Version as baked into Info.plist at build time (CI sets it from project.yml + run number).
enum AppInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
    static var display: String { "v\(version) (\(build))" }
}
