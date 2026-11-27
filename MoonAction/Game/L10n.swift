import Foundation

/// Bilingual text (English / 简体中文).
struct Text {
    let en: String
    let zh: String
    init(_ en: String, _ zh: String) {
        self.en = en
        self.zh = zh
    }
    var s: String { L10n.isZH ? zh : en }
}

enum L10n {
    /// "auto" follows the system language; "zh" / "en" force a language.
    static var setting: String {
        get { UserDefaults.standard.string(forKey: "moonaction.lang") ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: "moonaction.lang") }
    }

    static var isZH: Bool {
        switch setting {
        case "zh": return true
        case "en": return false
        default: return Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
        }
    }

    static func toggle() { setting = isZH ? "en" : "zh" }

    static let table: [String: (String, String)] = [
        "app.subtitle": ("3D CARD BATTLE", "3D 卡牌对战"),
        "home.battle": ("Battle", "开始战斗"),
        "home.stage": ("Stage %d", "第 %d 关"),
        "home.summon": ("Summon", "召唤"),
        "home.fighters": ("Fighters", "角色"),
        "home.help": ("How to Play", "玩法说明"),
        "home.footer": ("Original game · all characters are procedurally modeled 3D originals", "原创游戏 · 所有角色均为程序化建模的原创 3D 角色"),
        "home.record": ("%dW · %dL", "%d胜 · %d负"),
        "help.title": ("How to Play", "玩法说明"),
        "help.1": ("Tap cards to fight. Cards cost Energy; played cards are replaced from your deck.", "点击卡牌出招。卡牌消耗能量，打出后从牌组补充。"),
        "help.2": ("STRIKE (red): dash forward and attack in melee.", "拳击卡（红）：向前冲刺进行近身连打。"),
        "help.3": ("BLAST (gold): energy shots. They interrupt a strike that is dashing in.", "射击卡（金）：发射气弹，可打断冲刺中的对手。"),
        "help.4": ("SPECIAL (blue): signature art with a cinematic camera.", "必杀卡（蓝）：角色专属必杀技，带镜头演出。"),
        "help.5": ("EFFECT cards: heal, barrier, power-up, energy or curse.", "特殊卡：回复、护盾、强化、充能或诅咒。"),
        "help.6": ("ULTIMATE appears when the gold gauge is full.", "究极卡：金色槽满后出现。"),
        "help.7": ("Chain cards and keep hitting to build combos. Strikes during knockback CHASE with a teleport.", "连续出牌形成卡牌连携；对手被击飞时出拳卡会瞬移追击。"),
        "help.8": ("Swipe ←/→ to teleport-evade. Evade just before a hit for a PERFECT evade and counter.", "左右滑动瞬移闪避；在受击前一瞬闪避触发「完美闪避」并可反击。"),
        "help.9": ("Tap arena: basic attack · Swipe ↑: dash · ↓: step back · Hold: charge.", "点击场地：普通攻击 · 上滑：冲刺 · 下滑：后撤 · 长按：蓄力"),
        "help.10": ("Battles start at NEAR, MID or FAR range. Collect 7 moon shards for ECLIPSE RUSH.", "战斗以近/中/远三种距离开始。集齐 7 枚月之碎片发动「月蚀突袭」。"),
        "ok": ("Got it", "知道了"),
        "team.title": ("Choose Your Team", "选择队伍"),
        "team.sub": ("Pick 3 · the first one starts", "选择 3 名 · 第一位先出场"),
        "team.fight": ("Fight!", "出战！"),
        "team.locked": ("Locked", "未解锁"),
        "team.foes": ("Stage %d foes · Lv %d: %@", "第 %d 关对手 · Lv %d：%@"),
        "team.stats": ("HP %d   ATK %d   DEF %d", "体力 %d   攻击 %d   防御 %d"),
        "speed.fast": ("Fast teleport", "瞬移：快速"),
        "speed.medium": ("Medium teleport", "瞬移：中速"),
        "speed.slow": ("Slow teleport", "瞬移：慢速"),
        "summon.title": ("Summon", "召唤"),
        "summon.rates": ("★★ 75%  ·  ★★★ 25%  ·  duplicates +%d XP", "★★ 75%  ·  ★★★ 25%  ·  重复获得 +%d 经验"),
        "summon.button": ("Summon ×1", "召唤 ×1"),
        "summon.cost": ("%d moon coins", "%d 月币"),
        "summon.new": ("New fighter unlocked!", "解锁新角色！"),
        "summon.dup": ("+%d XP", "+%d 经验"),
        "summon.moves": ("Special · %@   Ultimate · %@", "必杀 · %@   究极 · %@"),
        "result.victory": ("Victory", "胜利"),
        "result.defeat": ("Defeat", "失败"),
        "result.cleared": ("Stage %d cleared · next: Stage %d", "第 %d 关通关 · 下一关：第 %d 关"),
        "result.retry": ("Train up and retry Stage %d", "提升实力后再挑战第 %d 关"),
        "result.continue": ("Continue", "继续"),
        "battle.ready": ("READY", "准备"),
        "battle.fight": ("FIGHT!", "开战！"),
        "battle.ko": ("K.O.", "击倒"),
        "battle.timeup": ("TIME UP", "时间到"),
        "battle.victory": ("VICTORY", "胜利"),
        "battle.defeat": ("DEFEAT", "失败"),
        "battle.hits": ("%d HITS", "%d 连击"),
        "battle.chain": ("CARD CHAIN ×%d", "卡牌连携 ×%d"),
        "battle.evade": ("EVADE", "闪避"),
        "battle.perfect": ("PERFECT EVADE", "完美闪避"),
        "battle.counter": ("COUNTER!", "反击！"),
        "battle.chase": ("CHASE!", "瞬移追击！"),
        "battle.escape": ("COMBO ESCAPE", "连击脱出"),
        "battle.tagin": ("TAG IN · %@", "换人 · %@"),
        "battle.energy": ("ENERGY", "能量"),
        "battle.next": ("NEXT", "下一张"),
        "battle.auto": ("AUTO", "自动"),
        "battle.autoOn": ("AUTO ON", "自动中"),
        "battle.paused": ("Paused", "暂停"),
        "battle.resume": ("Resume", "继续"),
        "battle.retreat": ("Retreat", "撤退"),
        "battle.ultimate": ("ULTIMATE ART", "究极技"),
        "battle.eclipse": ("ECLIPSE RUSH", "月蚀突袭"),
        "battle.atkup": ("ATK UP", "攻击提升"),
        "battle.defdown": ("DEF DOWN", "防御下降"),
        "battle.en": ("+%d EN", "+%d 能量"),
        "range.near": ("NEAR", "近距离"),
        "range.mid": ("MID", "中距离"),
        "range.far": ("FAR", "远距离"),
        "range.start": ("%@ START", "%@开局"),
        "kind.strike": ("STRIKE", "拳击"),
        "kind.blast": ("BLAST", "射击"),
        "kind.special": ("SPECIAL", "必杀"),
        "kind.ultimate": ("ULTIMATE", "究极"),
        "kind.team": ("TEAM", "合击"),
        "kind.heal": ("HEAL", "回复"),
        "kind.barrier": ("BARRIER", "护盾"),
        "kind.power": ("POWER", "强化"),
        "kind.energy": ("ENERGY", "充能"),
        "kind.curse": ("CURSE", "诅咒"),
        "lang": ("中文", "English"),
        "model.import": ("Import 3D Model", "导入3D模型"),
        "model.replace": ("Replace Model", "更换模型"),
        "model.remove": ("Remove", "移除"),
        "model.custom": ("Custom model · %d/10 bones mapped", "自定义模型 · 已识别骨骼 %d/10"),
        "model.bundled": ("Bundled model · %d/10 bones mapped", "内置模型 · 已识别骨骼 %d/10"),
        "model.procedural": ("Procedural model", "程序化模型"),
        "model.failed": ("Import failed", "导入失败"),
        "model.hint": (".usdz / .glb · humanoid rig (Mixamo, AccuRIG…)", ".usdz / .glb · 人形骨骼（Mixamo、AccuRIG 等）"),
    ]

    static func s(_ key: String) -> String {
        guard let e = table[key] else { return key }
        return isZH ? e.1 : e.0
    }

    static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: s(key), arguments: args)
    }
}

func L(_ key: String) -> String { L10n.s(key) }
