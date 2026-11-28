import SwiftUI
import UIKit
import BattleCore

/// Discrete HUD state. Values are only assigned when they change, so SwiftUI re-renders on
/// HP / Ki integers, hand and state changes — never every frame.
@MainActor
final class CoreHUDModel: ObservableObject {
    struct CardVM: Equatable, Identifiable {
        let id: Int
        let slot: Int
        let name: String
        let kind: BattleCore.CardKind
        let cost: Int
        let orb: Bool
        var playable: Bool
    }

    struct FighterVM: Equatable {
        var name = ""
        var element: BattleCore.Element = .lgt
        var hp = 0
        var maxHP = 1
        var portraitID = ""
    }

    struct BenchVM: Equatable, Identifiable {
        let id: Int            // team index
        let name: String
        let element: BattleCore.Element
        let hp: Double         // fraction
        let ko: Bool
        let image: UIImage?
    }

    @Published var bench: [BenchVM] = []
    @Published var switchCooldown = 0
    @Published var haptics = Haptics.enabled
    @Published var timer = 180
    @Published var player = FighterVM()
    @Published var enemy = FighterVM()
    @Published var enemyBench: [Double] = []     // HP fraction of benched enemies (KO = 0)
    @Published var ki = 0
    @Published var vanish = 100
    @Published var cards: [CardVM?] = [nil, nil, nil, nil]
    @Published var combo = 0
    @Published var zone: Zone = .mid
    @Published var orbs = 0
    @Published var locked = false
    @Published var paused = false
    @Published var auto = false
    /// Unique gauge (nil = fighter has none).
    @Published var gaugeType: UniqueGaugeType?
    @Published var gauge = 0
    @Published var overload = false
    @Published var canRush = false
    /// Clash bar 0…999 while a clash runs (nil otherwise); locked score once tapped.
    @Published var clashBar: Int?
    @Published var clashLocked: Int?
    enum RushMode: Equatable { case none, pick, guess, wait }
    @Published var rushMode: RushMode = .none
    var onRush: () -> Void = {}

    var onPlay: (Int) -> Void = { _ in }
    var onSwitch: (Int) -> Void = { _ in }
    var onHaptics: () -> Void = {}
    var onPause: () -> Void = {}
    var onResume: () -> Void = {}
    var onQuit: () -> Void = {}
    var onAuto: () -> Void = {}

    func set<T: Equatable>(_ kp: ReferenceWritableKeyPath<CoreHUDModel, T>, _ v: T) {
        if self[keyPath: kp] != v { self[keyPath: kp] = v }
    }

    /// Pull the discrete values out of the engine (cheap; only changed values publish).
    func sync(_ e: BattleEngine) {
        set(\.timer, Int(e.timer.rounded(.up)))
        let p = e.sides[0], q = e.sides[1]
        set(\.player, vm(p.current))
        set(\.enemy, vm(q.current))
        set(\.enemyBench, q.team.indices.filter { $0 != q.active }.map { max(0, q.team[$0].hp) / q.team[$0].maxHP })
        set(\.ki, Int(p.ki))
        set(\.vanish, Int(p.current.vanish))
        set(\.combo, p.comboHits)
        set(\.zone, e.zone)
        set(\.orbs, p.orbs)
        set(\.gaugeType, p.current.def.gauge)
        set(\.gauge, Int(p.current.gauge))
        set(\.overload, p.current.overload)
        set(\.canRush, e.canRush(side: 0))
        if let c = e.clash {
            set(\.clashBar, c.scores[0] ?? c.bar(at: e.time))
            set(\.clashLocked, c.scores[0])
        } else {
            set(\.clashBar, nil)
            set(\.clashLocked, nil)
        }
        if let r = e.rush {
            set(\.rushMode, r.attacker == 0 ? (r.landed ? .wait : .pick) : (r.landed && r.guess == nil ? .guess : .wait))
        } else {
            set(\.rushMode, .none)
        }
        set(\.locked, p.current.phase == .stunned)
        set(\.switchCooldown, Int(e.switchCooldown(side: 0).rounded(.up)))
        set(\.bench, p.team.indices.filter { $0 != p.active }.map { i in
            let f = p.team[i]
            return BenchVM(id: i, name: CoreVisuals.name(f.def), element: f.def.element, hp: max(0, f.hp) / f.maxHP, ko: f.isKO,
                           image: Portraits.image(CoreVisuals.visual(f.def), .bust, size: CGSize(width: 56, height: 56)))
        })
        let cards: [CardVM?] = (0..<4).map { i in
            guard let h = p.hand[i] else { return nil }
            return CardVM(id: h.id, slot: i, name: CoreVisuals.cardName(h.card), kind: h.card.kind,
                          cost: Int(e.cost(of: h.card, side: 0)), orb: h.orb, playable: e.canPlay(side: 0, slot: i))
        }
        set(\.cards, cards)
    }

    private func vm(_ f: FighterState) -> FighterVM {
        FighterVM(name: CoreVisuals.name(f.def), element: f.def.element, hp: Int(f.hp.rounded(.up)), maxHP: Int(f.maxHP),
                  portraitID: f.def.id)
    }
}

// MARK: - Views

private struct GlassBox: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 0.6))
    }
}

private extension View {
    func glassBox(_ r: CGFloat = 16) -> some View { modifier(GlassBox(radius: r)) }
}

struct ElementBadge: View {
    let element: BattleCore.Element
    var body: some View {
        SwiftUI.Text(L10n.isZH ? element.nameZH : element.nameEN)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 1.5)
            .background(Capsule().fill(Color(CoreVisuals.color(element)).opacity(0.85)))
            .foregroundStyle(Color.black.opacity(0.8))
    }
}

struct HPBar: View {
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(color).frame(width: max(0, g.size.width * fraction))
            }
        }
        .frame(height: 6)
        .animation(.easeOut(duration: 0.2), value: fraction)
    }
}

/// Top: pause / auto, timer, enemy portrait + HP + element, bench, zone, combo.
struct CoreTopHUD: View {
    @ObservedObject var m: CoreHUDModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                SwiftUI.Text("\(m.timer)")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .frame(width: 52, height: 52)
                    .glassBox(18)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        SwiftUI.Text(m.enemy.name).font(.system(size: 13, weight: .semibold))
                        ElementBadge(element: m.enemy.element)
                        Spacer()
                        SwiftUI.Text("\(m.enemy.hp)").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                    }
                    HPBar(fraction: Double(m.enemy.hp) / Double(max(1, m.enemy.maxHP)), color: Color(red: 1, green: 0.48, blue: 0.44))
                    HStack(spacing: 4) {
                        ForEach(Array(m.enemyBench.enumerated()), id: \.offset) { _, f in
                            Capsule().fill(f > 0 ? Color.white.opacity(0.55) : Color.white.opacity(0.12))
                                .frame(width: 34 * max(0.15, f), height: 3)
                                .frame(width: 34, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .glassBox(18)
            }
            HStack(spacing: 8) {
                Button(action: m.onPause) { Image(systemName: "pause.fill").font(.system(size: 12, weight: .bold)).frame(width: 32, height: 32) }
                    .glassBox(16)
                Button(action: m.onAuto) {
                    SwiftUI.Text(m.auto ? (L10n.isZH ? "自动中" : "AUTO ON") : (L10n.isZH ? "自动" : "AUTO"))
                        .font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).frame(height: 32)
                }
                .glassBox(16)
                Spacer()
                SwiftUI.Text(zoneName).font(.system(size: 10, weight: .semibold)).padding(.horizontal, 10).frame(height: 24).glassBox(12)
                Spacer()
                SwiftUI.Text(m.combo >= 2 ? "\(m.combo) " + (L10n.isZH ? "连击" : "HITS") : " ")
                    .font(.system(size: 18, weight: .heavy)).foregroundStyle(Color(Theme.accent))
                    .frame(width: 96, alignment: .trailing)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: m.combo)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
    }

    private var zoneName: String {
        switch m.zone {
        case .close: return L10n.isZH ? "近距离" : "CLOSE"
        case .mid: return L10n.isZH ? "中距离" : "MID"
        case .long: return L10n.isZH ? "远距离" : "LONG"
        }
    }
}

/// Bottom: player status (HP, vanish, Ki, orbs) and the 4 card slots.
struct CoreBottomHUD: View {
    @ObservedObject var m: CoreHUDModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(m.bench) { b in
                    BenchButton(vm: b, cooldown: m.switchCooldown, highlight: m.locked) { m.onSwitch(b.id) }
                }
                if m.locked {
                    SwiftUI.Text(m.switchCooldown == 0 ? (L10n.isZH ? "受击中 · 点头像援护换人" : "COMBO'D · tap to cover")
                                                       : (L10n.isZH ? "受击中" : "COMBO'D"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 1, green: 0.48, blue: 0.44))
                }
                Spacer()
            }
            if m.rushMode != .none {
                SwiftUI.Text(rushPrompt).font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(Theme.accent))
            }
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    CardSlot(card: m.cards[i]) { m.onPlay(i) }
                }
                if m.canRush {
                    Button(action: m.onRush) {
                        VStack(spacing: 2) {
                            Image(systemName: "sparkles").font(.system(size: 18, weight: .bold))
                            SwiftUI.Text(L10n.isZH ? "升龙" : "RUSH").font(.system(size: 10, weight: .heavy))
                        }
                        .frame(width: 52, height: 72)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(Theme.accent).opacity(0.9)))
                        .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    SwiftUI.Text(m.player.name).font(.system(size: 13, weight: .semibold))
                    ElementBadge(element: m.player.element)
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { i in
                            Circle().fill(i < m.orbs ? Color(Theme.accent) : Color.white.opacity(0.15)).frame(width: 5, height: 5)
                        }
                    }
                    SwiftUI.Text("\(m.player.hp)").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                }
                HPBar(fraction: Double(m.player.hp) / Double(max(1, m.player.maxHP)), color: Color(red: 0.49, green: 0.89, blue: 0.66))
                if let g = m.gaugeType {
                    KiGauge(label: m.overload ? (L10n.isZH ? "超载" : "OVERLOAD") : (L10n.isZH ? g.nameZH : g.rawValue.uppercased()),
                            value: m.overload ? 100 : m.gauge, color: Self.gaugeColor(g))
                        .opacity(m.gauge >= 100 || m.overload ? 1 : 0.85)
                }
                HStack(spacing: 8) {
                    KiGauge(label: L10n.isZH ? "闪避" : "VANISH", value: m.vanish, color: Color(red: 0.5, green: 0.85, blue: 1))
                    KiGauge(label: L10n.isZH ? "气力" : "KI", value: m.ki, color: Color(Theme.accent))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassBox(20)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
    }

    private var rushPrompt: String {
        switch m.rushMode {
        case .pick: return L10n.isZH ? "升龙冲击！选择一张卡 · PICK A CARD" : "RISING RUSH! Pick a card"
        case .guess: return L10n.isZH ? "对手升龙！猜中他的卡 · GUESS 1 OF 4" : "ENEMY RUSH! Guess 1 of 4"
        case .wait, .none: return L10n.isZH ? "升龙冲击 · RISING RUSH" : "RISING RUSH"
        }
    }

    static func gaugeColor(_ g: UniqueGaugeType) -> Color {
        switch g {
        case .attack: return Color(red: 1, green: 0.45, blue: 0.25)
        case .autoEvade: return Color(red: 0.85, green: 0.9, blue: 1)
        case .counter: return Color(red: 0.8, green: 0.6, blue: 1)
        case .release: return Color(red: 0.4, green: 0.75, blue: 1)
        }
    }
}

/// Strike clash: a fast 0–999 bar; tap anywhere to lock.
struct CoreClashOverlay: View {
    @ObservedObject var m: CoreHUDModel
    var body: some View {
        if let v = m.clashBar {
            VStack(spacing: 10) {
                SwiftUI.Text(L10n.isZH ? "拼招！点击锁定 · CLASH! TAP" : "CLASH! TAP TO LOCK").font(.system(size: 20, weight: .black)).italic()
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule().fill(LinearGradient(colors: [.orange, .yellow, .white], startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * CGFloat(v) / 999)
                    }
                }
                .frame(height: 14)
                SwiftUI.Text("\(v)").font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(m.clashLocked != nil ? Color(Theme.accent) : .white)
            }
            .padding(18)
            .glassBox(20)
            .padding(.horizontal, 40)
            .foregroundStyle(.white)
            .allowsHitTesting(false)
        }
    }
}

/// Benched teammate: portrait with element ring, HP arc, cooldown overlay. Tap to tag in.
private struct BenchButton: View {
    let vm: CoreHUDModel.BenchVM
    let cooldown: Int
    let highlight: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            ZStack {
                Circle().fill(Color.black.opacity(0.5))
                if let img = vm.image {
                    Image(uiImage: img).resizable().scaledToFill().clipShape(Circle()).padding(3)
                }
                Circle().trim(from: 0, to: vm.hp).stroke(Color(red: 0.49, green: 0.89, blue: 0.66), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(1.5)
                Circle().stroke(Color(CoreVisuals.color(vm.element)).opacity(0.9), lineWidth: 1).padding(5)
                if vm.ko {
                    Circle().fill(Color.black.opacity(0.65))
                    Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                } else if cooldown > 0 {
                    Circle().fill(Color.black.opacity(0.55))
                    SwiftUI.Text("\(cooldown)").font(.system(size: 16, weight: .heavy, design: .rounded))
                }
            }
            .frame(width: 50, height: 50)
            .overlay(Circle().stroke(Color(Theme.accent), lineWidth: highlight && cooldown == 0 && !vm.ko ? 2 : 0).padding(-3))
        }
        .buttonStyle(.plain)
        .disabled(vm.ko || cooldown > 0)
    }
}

private struct KiGauge: View {
    let label: String
    let value: Int
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            SwiftUI.Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            HPBar(fraction: Double(value) / 100, color: color)
            SwiftUI.Text("\(value)").font(.system(size: 11, weight: .semibold, design: .monospaced)).frame(width: 26, alignment: .trailing)
        }
    }
}

private struct CardSlot: View {
    let card: CoreHUDModel.CardVM?
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.55), Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(tint.opacity(0.9), lineWidth: 1.2)
                if let c = card {
                    VStack(spacing: 4) {
                        HStack {
                            SwiftUI.Text("\(c.cost)").font(.system(size: 13, weight: .heavy, design: .rounded))
                                .frame(width: 24, height: 24).background(Circle().fill(.black.opacity(0.55)))
                            Spacer()
                            if c.orb { Image(systemName: "star.circle.fill").font(.system(size: 14)).foregroundStyle(Color(Theme.accent)) }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: CoreVisuals.kindSymbol(c.kind)).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
                        Spacer(minLength: 0)
                        SwiftUI.Text(CoreVisuals.kindName(c.kind)).font(.system(size: 8, weight: .bold)).foregroundStyle(tint)
                        SwiftUI.Text(c.name).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(6)
                } else {
                    ProgressView().tint(.white.opacity(0.5))
                }
            }
            .aspectRatio(0.72, contentMode: .fit)
            .opacity(card?.playable == true ? 1 : 0.4)
            .scaleEffect(card?.playable == true ? 1 : 0.96)
            .animation(.easeOut(duration: 0.15), value: card?.playable)
        }
        .buttonStyle(.plain)
        .disabled(card == nil)
    }

    private var tint: Color { card.map { Color(CoreVisuals.kindColor($0.kind)) } ?? .gray }
}

struct CorePauseOverlay: View {
    @ObservedObject var m: CoreHUDModel
    var body: some View {
        if m.paused {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(spacing: 14) {
                    SwiftUI.Text(L10n.isZH ? "已暂停" : "Paused").font(.system(size: 20, weight: .semibold))
                    Button(action: m.onResume) {
                        SwiftUI.Text(L10n.isZH ? "继续" : "Resume").font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(Color(Theme.accent))).foregroundStyle(.black)
                    }
                    Button(action: m.onHaptics) {
                        HStack {
                            Image(systemName: m.haptics ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                            SwiftUI.Text(m.haptics ? (L10n.isZH ? "震动：开" : "Vibration: On") : (L10n.isZH ? "震动：关" : "Vibration: Off"))
                        }
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .glassBox(20)
                    Button(action: m.onQuit) {
                        SwiftUI.Text(L10n.isZH ? "退出战斗" : "Quit").font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .glassBox(20)
                }
                .padding(24).frame(width: 300).glassBox(28)
            }
            .foregroundStyle(.white)
        }
    }
}
