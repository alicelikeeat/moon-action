import AVFoundation

/// All sound effects are synthesized at launch — no audio assets ship with the game.
enum SFX: CaseIterable {
    case hit, heavy, blast, beam, dodge, card, ko, charge, ui, explode, ultimate
}

@MainActor
final class Sound {
    static let shared = Sound()
    private var pools: [SFX: [AVAudioPlayer]] = [:]
    private var cursor: [SFX: Int] = [:]
    var enabled = true

    private init() {
        for s in SFX.allCases {
            let data = Sound.wav(Sound.synth(s))
            var players: [AVAudioPlayer] = []
            for _ in 0..<3 {
                if let p = try? AVAudioPlayer(data: data) {
                    p.volume = Sound.volume(s)
                    p.prepareToPlay()
                    players.append(p)
                }
            }
            pools[s] = players
        }
    }

    static func play(_ s: SFX) { shared.play(s) }

    func play(_ s: SFX) {
        guard enabled, let players = pools[s], !players.isEmpty else { return }
        let i = (cursor[s] ?? 0) % players.count
        cursor[s] = i + 1
        let p = players[i]
        p.currentTime = 0
        p.play()
    }

    private static let rate = 22050

    private static func volume(_ s: SFX) -> Float {
        switch s {
        case .ui, .card: return 0.35
        case .charge: return 0.3
        case .beam, .ultimate, .explode: return 0.55
        default: return 0.45
        }
    }

    private static func gen(_ dur: Double, _ f: (Double, Double) -> Double) -> [Float] {
        let n = Int(dur * Double(rate))
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / Double(rate)
            out[i] = Float(f(t, t / dur))
        }
        return out
    }

    private static func noise() -> Double { Double.random(in: -1...1) }

    /// Frequency sweep phase: integral of a linear chirp.
    private static func chirp(_ t: Double, _ f0: Double, _ f1: Double, _ dur: Double) -> Double {
        sin(2 * Double.pi * (f0 * t + (f1 - f0) * t * t / (2 * dur)))
    }

    private static func synth(_ s: SFX) -> [Float] {
        switch s {
        case .hit:
            return gen(0.12) { t, p in (noise() * 0.55 + chirp(t, 220, 90, 0.12) * 0.7) * pow(1 - p, 3) }
        case .heavy:
            return gen(0.3) { t, p in (noise() * 0.6 + chirp(t, 160, 45, 0.3) * 0.9) * pow(1 - p, 2.2) }
        case .blast:
            return gen(0.3) { t, p in (chirp(t, 900, 180, 0.3) * 0.55 + noise() * 0.3) * pow(1 - p, 1.6) }
        case .beam:
            return gen(1.1) { t, p in
                let env = min(1, p * 12) * pow(1 - p, 0.8)
                return (noise() * 0.45 + sin(2 * Double.pi * 110 * t) * 0.4 + sin(2 * Double.pi * 223 * t) * 0.2) * env
            }
        case .dodge:
            return gen(0.18) { t, p in noise() * 0.5 * sin(Double.pi * p) + chirp(t, 300, 1400, 0.18) * 0.15 * (1 - p) }
        case .card:
            return gen(0.05) { t, p in sin(2 * Double.pi * 1300 * t) * pow(1 - p, 2) * 0.6 }
        case .ui:
            return gen(0.08) { t, p in sin(2 * Double.pi * 880 * t) * pow(1 - p, 2) * 0.6 }
        case .ko:
            return gen(0.8) { t, p in (chirp(t, 400, 60, 0.8) * 0.6 + noise() * 0.3) * pow(1 - p, 1.5) }
        case .charge:
            return gen(0.5) { t, p in (chirp(t, 120, 520, 0.5) * 0.4 + noise() * 0.15) * sin(Double.pi * p) }
        case .explode:
            return gen(0.9) { t, p in (noise() * 0.8 + sin(2 * Double.pi * 55 * t) * 0.6) * pow(1 - p, 2) }
        case .ultimate:
            return gen(1.0) { t, p in
                (sin(2 * Double.pi * 220 * t) * 0.3 + sin(2 * Double.pi * 330 * t) * 0.25 + sin(2 * Double.pi * 440 * t) * 0.2)
                    * min(1, p * 6) * pow(1 - p, 1.2)
            }
        }
    }

    private static func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let dataSize = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + dataSize)
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(dataSize)
        for s in samples {
            let v = Int16(max(-1, min(1, s)) * 32000)
            u16(UInt16(bitPattern: v))
        }
        return d
    }
}
