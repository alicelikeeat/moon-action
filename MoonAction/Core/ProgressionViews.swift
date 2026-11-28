import SwiftUI
import CoreMotion
import BattleCore

// MARK: - Shared bits

private extension View {
    func card(_ r: CGFloat = 18) -> some View {
        background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: r, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 0.6))
    }
}

private func zh(_ zh: String, _ en: String) -> String { L10n.isZH ? zh : en }

private func rarityColor(_ r: Rarity) -> Color {
    switch r {
    case .sp: return Color(red: 0.75, green: 0.8, blue: 0.9)
    case .ll: return Color(red: 1, green: 0.78, blue: 0.3)
    case .ul: return Color(red: 0.95, green: 0.45, blue: 1)
    }
}

private func gradeColor(_ g: EquipGrade) -> Color {
    switch g {
    case .b: return .gray
    case .a: return Color(red: 0.4, green: 0.8, blue: 0.5)
    case .s: return Color(red: 0.4, green: 0.7, blue: 1)
    case .z: return Color(red: 0.75, green: 0.5, blue: 1)
    case .zPlus: return Color(red: 1, green: 0.7, blue: 0.25)
    case .godly: return Color(red: 1, green: 0.35, blue: 0.3)
    }
}

private func beadColor(_ b: Bead) -> Color {
    switch b {
    case .green: return Color(red: 0.45, green: 0.85, blue: 0.5)
    case .gold: return Color(red: 1, green: 0.8, blue: 0.3)
    case .red: return Color(red: 1, green: 0.35, blue: 0.3)
    }
}

private func statText(_ v: Double) -> String { v >= 1000 ? Int(v).formatted() : String(format: "%.0f", v) }

struct RarityBadge: View {
    let rarity: Rarity
    var body: some View {
        SwiftUI.Text(rarity.label)
            .font(.system(size: 10, weight: .black)).italic()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(rarityColor(rarity)))
            .foregroundStyle(.black)
    }
}

struct PortraitImage: View {
    let def: BattleCore.FighterDef
    var size: CGFloat = 56
    var body: some View {
        let img = Portraits.image(CoreVisuals.visual(def), .bust, size: CGSize(width: size, height: size)) ?? UIImage()
        Image(uiImage: img)
            .resizable().scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).stroke(Color(CoreVisuals.color(def.element)), lineWidth: 1.5))
    }
}

// MARK: - Root (tabs)

/// Out-of-battle hub: team select, fighter progression, equipment forge.
struct ProgressionRootView: View {
    @ObservedObject var save: CoreSave
    var onBattle: () -> Void
    var onBack: () -> Void
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onBack) { Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).padding(10).card(14) }
                Spacer()
                MaterialsBar(m: save.data.materials)
            }
            Picker("", selection: $tab) {
                SwiftUI.Text(zh("编队", "Team")).tag(0)
                SwiftUI.Text(zh("角色", "Fighters")).tag(1)
                SwiftUI.Text(zh("装备", "Forge")).tag(2)
            }
            .pickerStyle(.segmented)
            switch tab {
            case 0: TeamSelectView(save: save, onBattle: onBattle)
            case 1: FighterListView(save: save)
            default: EquipmentForgeView(save: save)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}

struct MaterialsBar: View {
    let m: UserSaveData.Materials
    var body: some View {
        HStack(spacing: 10) {
            item("book.fill", m.expBooks, .cyan)
            item("star.fill", m.starSouls, .yellow)
            item("hammer.fill", m.reforgeStones, .orange)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .card(14)
    }
    private func item(_ s: String, _ v: Int, _ c: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: s).foregroundStyle(c).font(.system(size: 11))
            SwiftUI.Text("\(v)").font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
    }
}

// MARK: - Team select

struct TeamSelectView: View {
    @ObservedObject var save: CoreSave
    var onBattle: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SwiftUI.Text(zh("出战队伍 · 第 1 位为队长", "Team · first slot is the leader")).font(.system(size: 12, weight: .bold)).opacity(0.75)
                    HStack(spacing: 10) {
                        ForEach(Array(save.data.team.enumerated()), id: \.offset) { i, id in
                            if let d = FighterRoster.byID(id) {
                                VStack(spacing: 4) {
                                    PortraitImage(def: d, size: 72)
                                        .overlay(alignment: .topLeading) {
                                            if i == 0 {
                                                Image(systemName: "crown.fill").font(.system(size: 13)).foregroundStyle(.yellow).padding(4)
                                            }
                                        }
                                    SwiftUI.Text(CoreVisuals.name(d)).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                                    RarityBadge(rarity: d.rarity)
                                }
                                .frame(maxWidth: .infinity)
                                .onTapGesture { removeOrLead(id) }
                            }
                        }
                    }
                    if let lead = save.data.team.first.flatMap(FighterRoster.byID) {
                        SwiftUI.Text(leaderText(lead)).font(.system(size: 11)).opacity(0.8)
                    }
                }
                .padding(14).card()

                VStack(alignment: .leading, spacing: 8) {
                    SwiftUI.Text(zh("点击加入 / 点击队员设为队长", "Tap to add · tap a member to lead")).font(.system(size: 12, weight: .bold)).opacity(0.75)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                        ForEach(FighterRoster.all) { d in
                            let inTeam = save.data.team.contains(d.id)
                            VStack(spacing: 3) {
                                PortraitImage(def: d, size: 60).opacity(inTeam ? 0.4 : 1)
                                SwiftUI.Text("Lv.\(save.data.progress(d.id).level) · \(save.data.progress(d.id).stars)★")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                            }
                            .onTapGesture { add(d.id) }
                        }
                    }
                }
                .padding(14).card()

                Picker(zh("难度", "Difficulty"), selection: Binding(get: { save.data.difficulty }, set: { save.data.difficulty = $0 })) {
                    SwiftUI.Text(zh("新手", "Novice")).tag("novice")
                    SwiftUI.Text(zh("标准", "Standard")).tag("standard")
                    SwiftUI.Text(zh("挑战", "Challenge")).tag("challenge")
                }
                .pickerStyle(.segmented)

                Button(action: onBattle) {
                    HStack {
                        Image(systemName: "play.fill")
                        SwiftUI.Text(zh("出战", "BATTLE")).font(.system(size: 18, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(Theme.accent)))
                    .foregroundStyle(.black)
                }
                .disabled(save.data.team.count < 3)
                SwiftUI.Text(zh("战绩 \(save.data.wins) 胜 \(save.data.losses) 负", "Record \(save.data.wins)W \(save.data.losses)L"))
                    .font(.system(size: 11)).opacity(0.6)
            }
            .padding(.bottom, 30)
        }
    }

    private func leaderText(_ d: BattleCore.FighterDef) -> String {
        if d.rarity == .ul { return zh("ULTRA 能力：全队伤害 +30%、气力回复 +30%", "ULTRA ability: team +30% damage & Ki recovery") }
        return zh("队长 Z 能力对全队生效（\(d.zAbility.tag.nameZH)）", "Leader's Z ability applies to the whole team")
    }

    private func add(_ id: String) {
        guard !save.data.team.contains(id) else { return }
        if save.data.team.count >= 3 { save.data.team.removeLast() }
        save.data.team.append(id)
        Haptics.select()
    }

    private func removeOrLead(_ id: String) {
        guard let i = save.data.team.firstIndex(of: id) else { return }
        if i == 0 {
            save.data.team.remove(at: 0)
        } else {
            save.data.team.swapAt(0, i)
        }
        Haptics.select()
    }
}

// MARK: - Fighters

struct FighterListView: View {
    @ObservedObject var save: CoreSave
    @State private var selected: String?

    var body: some View {
        if let id = selected, let d = FighterRoster.byID(id) {
            CharacterDetailView(save: save, def: d) { selected = nil }
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(FighterRoster.all) { d in
                        let p = save.data.progress(d.id)
                        HStack(spacing: 12) {
                            PortraitImage(def: d, size: 54)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    SwiftUI.Text(CoreVisuals.name(d)).font(.system(size: 14, weight: .semibold))
                                    RarityBadge(rarity: d.rarity)
                                    ElementBadge(element: d.element)
                                }
                                SwiftUI.Text("Lv.\(p.level) · \(String(repeating: "★", count: min(p.stars, 7)))\(p.stars > 7 ? "+\(p.stars - 7)" : "")")
                                    .font(.system(size: 11, design: .monospaced)).opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").opacity(0.5)
                        }
                        .padding(10).card(16)
                        .onTapGesture { selected = d.id }
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
}

/// Gyro parallax for UL cards.
@MainActor
final class MotionModel: ObservableObject {
    @Published var tilt = CGSize.zero
    private let mgr = CMMotionManager()

    func start() {
        guard mgr.isDeviceMotionAvailable, !mgr.isDeviceMotionActive else { return }
        mgr.deviceMotionUpdateInterval = 1.0 / 30
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let a = m?.attitude else { return }
            self?.tilt = CGSize(width: max(-1, min(1, a.roll)), height: max(-1, min(1, a.pitch - 0.6)))
        }
    }

    func stop() { mgr.stopDeviceMotionUpdates() }
}

struct CharacterDetailView: View {
    @ObservedObject var save: CoreSave
    let def: BattleCore.FighterDef
    var onBack: () -> Void
    @StateObject private var motion = MotionModel()
    @State private var picking: Int?

    private var p: UserSaveData.FighterProgress { save.data.progress(def.id) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Button(action: onBack) { Label(zh("返回", "Back"), systemImage: "chevron.left").font(.system(size: 13, weight: .semibold)) }
                    Spacer()
                }
                portraitCard
                statsCard
                levelCard
                equipmentCard
                kitCard
            }
            .padding(.bottom, 30)
        }
        .onAppear { if def.rarity == .ul { motion.start() } }
        .onDisappear { motion.stop() }
        .sheet(item: Binding(get: { picking.map { PickSlot(slot: $0) } }, set: { picking = $0?.slot })) { s in
            EquipPicker(save: save, def: def, slot: s.slot) { picking = nil }
        }
    }

    private struct PickSlot: Identifiable { let slot: Int; var id: Int { slot } }

    private var portraitCard: some View {
        let t = motion.tilt
        return ZStack {
            RoundedRectangle(cornerRadius: 22).fill(LinearGradient(colors: [Color(CoreVisuals.color(def.element)).opacity(0.6), .black.opacity(0.6)],
                                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
            if def.rarity == .ul {
                // Gyro light sweep across the UL card.
                LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 90).rotationEffect(.degrees(20))
                    .offset(x: t.width * 140, y: t.height * 30)
                    .blendMode(.plusLighter)
            }
            HStack(spacing: 14) {
                PortraitImage(def: def, size: 120)
                    .offset(x: t.width * 8, y: t.height * 6)
                VStack(alignment: .leading, spacing: 6) {
                    HStack { RarityBadge(rarity: def.rarity); ElementBadge(element: def.element) }
                    SwiftUI.Text(CoreVisuals.name(def)).font(.system(size: 20, weight: .heavy))
                    SwiftUI.Text(def.roleZH).font(.system(size: 12)).opacity(0.8)
                    SwiftUI.Text(def.tags.map(\.nameZH).joined(separator: " · ")).font(.system(size: 10)).opacity(0.7)
                }
                Spacer()
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .rotation3DEffect(.degrees(Double(t.width) * 8), axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(Double(-t.height) * 6), axis: (x: 1, y: 0, z: 0))
    }

    private var statsCard: some View {
        let s = TeamBuild.finalStats(team: [save.data.loadout(def.id) ?? FighterLoadout(def: def)])[0]
        return VStack(alignment: .leading, spacing: 6) {
            SwiftUI.Text(zh("面板（含 Z 能力与装备）", "Stats (Z ability + equipment)")).font(.system(size: 12, weight: .bold)).opacity(0.75)
            HStack {
                stat(zh("体力", "HP"), s.hp)
                stat(zh("打击", "Strike"), s.strikeAtk)
                stat(zh("射击", "Blast"), s.blastAtk)
                stat(zh("防御", "Def"), s.defense)
            }
            SwiftUI.Text(zh("Z 能力 \(["I", "II", "III", "IV"][ZAbility.tier(stars: p.stars)])：\(def.zAbility.tag.nameZH) +\(Int(def.zAbility.value(stars: p.stars) * 100))%",
                            "Z ability \(["I", "II", "III", "IV"][ZAbility.tier(stars: p.stars)]): +\(Int(def.zAbility.value(stars: p.stars) * 100))%"))
                .font(.system(size: 11)).opacity(0.8)
        }
        .padding(14).card()
    }

    private func stat(_ l: String, _ v: Double) -> some View {
        VStack(spacing: 2) {
            SwiftUI.Text(l).font(.system(size: 10)).opacity(0.7)
            SwiftUI.Text(statText(v)).font(.system(size: 13, weight: .semibold, design: .monospaced)).minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SwiftUI.Text("Lv.\(p.level) / 5000").font(.system(size: 15, weight: .heavy, design: .monospaced))
                Spacer()
                SwiftUI.Text("\(p.stars)★ / 14★").font(.system(size: 15, weight: .heavy, design: .monospaced)).foregroundStyle(.yellow)
            }
            ProgressView(value: Double(p.level), total: 5000).tint(.cyan)
            HStack(spacing: 8) {
                ForEach([10, 100, 1000], id: \.self) { n in
                    Button("+\(n)") { save.data.levelUp(def.id, by: n); Haptics.select() }
                        .buttonStyle(.bordered).disabled(p.level >= 5000 || save.data.materials.expBooks == 0)
                }
                Button(zh("满级", "MAX")) { save.data.maxLevel(def.id); Haptics.success() }.buttonStyle(.bordered).tint(.cyan)
            }
            HStack {
                Button(zh("升星（\(Progression.starCost(from: p.stars)) 星魂）", "Star up (\(Progression.starCost(from: p.stars)) souls)")) {
                    if save.data.starUp(def.id) { Haptics.success() }
                }
                .buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
                .disabled(p.stars >= 14 || save.data.materials.starSouls < Progression.starCost(from: p.stars))
                Spacer()
            }
        }
        .padding(14).card()
    }

    private var equipmentCard: some View {
        let unlocked = Progression.equipmentSlots(level: p.level)
        return VStack(alignment: .leading, spacing: 8) {
            SwiftUI.Text(zh("装备槽（Lv.1000 / 3000 解锁第 2 / 3 槽）", "Equipment (slots 2 / 3 at Lv.1000 / 3000)"))
                .font(.system(size: 12, weight: .bold)).opacity(0.75)
            ForEach(0..<3, id: \.self) { slot in
                let id = p.equipped.indices.contains(slot) ? p.equipped[slot] : -1
                let item = save.data.inventory.first { $0.id == id }
                Button { if slot < unlocked { picking = slot } } label: {
                    HStack {
                        Image(systemName: slot < unlocked ? "shield.lefthalf.filled" : "lock.fill").frame(width: 22)
                        if let item { ItemRow(item: item) } else {
                            SwiftUI.Text(slot < unlocked ? zh("空 · 点击装备", "Empty · tap to equip") : zh("未解锁", "Locked"))
                                .font(.system(size: 12)).opacity(0.6)
                            Spacer()
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14).card()
    }

    private var kitCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SwiftUI.Text(zh("招式", "Arts")).font(.system(size: 12, weight: .bold)).opacity(0.75)
            ForEach(def.deck + [def.ultimate], id: \.id) { c in
                HStack {
                    Circle().fill(Color(CoreVisuals.kindColor(c.kind))).frame(width: 8, height: 8)
                    SwiftUI.Text(CoreVisuals.cardName(c)).font(.system(size: 12))
                    Spacer()
                    SwiftUI.Text("\(c.cost) Ki").font(.system(size: 11, design: .monospaced)).opacity(0.7)
                }
            }
            if let g = def.gauge {
                SwiftUI.Text(zh("特殊量表：\(g.nameZH)", "Unique gauge: \(g.rawValue)")).font(.system(size: 11)).opacity(0.85).padding(.top, 4)
            }
            SwiftUI.Text(zh("主能力 \(Int(def.ability.unlockTime)) 秒后可用", "Main ability after \(Int(def.ability.unlockTime)) s"))
                .font(.system(size: 11)).opacity(0.7)
        }
        .padding(14).card()
    }
}

struct ItemRow: View {
    let item: EquipmentItem
    var body: some View {
        HStack(spacing: 8) {
            SwiftUI.Text(item.grade.rawValue).font(.system(size: 13, weight: .black)).frame(width: 26)
                .foregroundStyle(gradeColor(item.grade))
            VStack(alignment: .leading, spacing: 2) {
                SwiftUI.Text(L10n.isZH ? item.template?.nameZH ?? "?" : item.template?.nameEN ?? "?").font(.system(size: 12, weight: .semibold))
                HStack(spacing: 6) {
                    ForEach(0..<(item.template?.slots.count ?? 0), id: \.self) { i in
                        HStack(spacing: 2) {
                            Circle().fill(beadColor(item.bead(slot: i))).frame(width: 7, height: 7)
                            SwiftUI.Text("\(item.template!.slots[i].stat.nameZH) +\(Int((item.value(slot: i) * 100).rounded()))%")
                                .font(.system(size: 9, design: .monospaced)).opacity(0.85)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct EquipPicker: View {
    @ObservedObject var save: CoreSave
    let def: BattleCore.FighterDef
    let slot: Int
    var done: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(save.data.inventory.filter { $0.template?.canEquip(def) ?? false }) { item in
                    Button {
                        if save.data.equip(itemID: item.id, to: def.id, slot: slot) { Haptics.success() }
                        done()
                    } label: { ItemRow(item: item) }
                }
            }
            .navigationTitle(zh("选择装备", "Choose equipment"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(zh("取消", "Cancel"), action: done) } }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Equipment forge

struct EquipmentForgeView: View {
    @ObservedObject var save: CoreSave
    @State private var secure = false
    @State private var rng = SplitMix64(seed: UInt64.random(in: 1...UInt64.max))

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Toggle(isOn: $secure) {
                    VStack(alignment: .leading, spacing: 2) {
                        SwiftUI.Text(zh("安全升级模式（3 石）", "Secure upgrade (3 stones)")).font(.system(size: 13, weight: .semibold))
                        SwiftUI.Text(zh("重铸结果不会低于原值", "Reroll never goes below the current value")).font(.system(size: 10)).opacity(0.7)
                    }
                }
                .padding(12).card(14)
                ForEach(save.data.inventory.sorted { $0.grade > $1.grade }) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        ItemRow(item: item)
                        HStack(spacing: 8) {
                            ForEach([1, 2], id: \.self) { s in
                                Button(zh("重铸第 \(s + 1) 槽", "Reforge slot \(s + 1)")) {
                                    if save.data.reforge(itemID: item.id, slot: s, secure: secure, rng: &rng) { Haptics.select() }
                                }
                                .buttonStyle(.bordered)
                                .disabled(save.data.materials.reforgeStones < (secure ? 3 : 1))
                            }
                            Spacer()
                            if let who = wearer(item.id) {
                                SwiftUI.Text(zh("装备于 \(who)", "on \(who)")).font(.system(size: 10)).opacity(0.6)
                            }
                        }
                    }
                    .padding(12).card(14)
                }
                if save.data.inventory.isEmpty {
                    SwiftUI.Text(zh("还没有装备 · 战斗胜利掉落", "No equipment yet · win battles for drops")).opacity(0.6)
                }
            }
            .padding(.bottom, 30)
        }
    }

    private func wearer(_ id: Int) -> String? {
        save.data.fighters.first { $0.value.equipped.contains(id) }.flatMap { FighterRoster.byID($0.key) }.map(CoreVisuals.name)
    }
}

// MARK: - Result

struct CoreResultView: View {
    let won: Bool
    let legendary: Bool
    let rewards: (books: Int, souls: Int, stones: Int, item: EquipmentItem?)
    let damage: Int
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if legendary {
                SwiftUI.Text("LEGENDARY FINISH").font(.system(size: 22, weight: .black)).italic()
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
            }
            SwiftUI.Text(won ? zh("胜利", "VICTORY") : zh("战败", "DEFEAT")).font(.system(size: 40, weight: .black))
                .foregroundStyle(won ? Color(Theme.accent) : Color(Theme.hpEnemy))
            SwiftUI.Text(zh("总伤害 \(damage.formatted())", "Total damage \(damage.formatted())")).font(.system(size: 13, design: .monospaced))
            VStack(alignment: .leading, spacing: 8) {
                SwiftUI.Text(zh("奖励", "Rewards")).font(.system(size: 12, weight: .bold)).opacity(0.75)
                Label(zh("经验书 +\(rewards.books)", "EXP books +\(rewards.books)"), systemImage: "book.fill")
                Label(zh("星魂 +\(rewards.souls)", "Star souls +\(rewards.souls)"), systemImage: "star.fill")
                Label(zh("洗练石 +\(rewards.stones)", "Reforge stones +\(rewards.stones)"), systemImage: "hammer.fill")
                if let item = rewards.item { ItemRow(item: item) }
            }
            .font(.system(size: 13))
            .padding(16).card()
            Button(action: onContinue) {
                SwiftUI.Text(zh("继续", "CONTINUE")).font(.system(size: 17, weight: .heavy))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(Theme.accent)))
                    .foregroundStyle(.black)
            }
        }
        .padding(24)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}
