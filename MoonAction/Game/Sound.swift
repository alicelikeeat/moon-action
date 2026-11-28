import AVFoundation

/// All sound effects are synthesized at launch — no audio assets ship with the game.
enum SFX: CaseIterable {
    case hit, heavy, blast, beam, dodge, card, ko, charge, ui, explode, ultimate
    case whoosh, crack, thud, slap, zap, boom
}

/// Synthesized SFX played through AVAudioEngine: a pool of player voices, each through a varispeed unit
/// so per-card signatures can shift pitch + speed together. Falls back to silence if the engine cannot start.
@MainActor
final class Sound {
    static let shared = Sound()
    private let engine = AVAudioEngine()
    private var buffers: [SFX: AVAudioPCMBuffer] = [:]
    private var voices: [(player: AVAudioPlayerNode, speed: AVAudioUnitVarispeed)] = []
    private var cursor = 0
    private var running = false
    var enabled = true

    private init() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(Sound.rate), channels: 1) else { return }
        for s in SFX.allCases {
            let samples = Sound.synth(s)
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
                  let ch = buf.floatChannelData?[0] else { continue }
            let v = Sound.volume(s)
            for (i, x) in samples.enumerated() { ch[i] = max(-1, min(1, x)) * v }
            buf.frameLength = AVAudioFrameCount(samples.count)
            buffers[s] = buf
        }
        for _ in 0..<10 {
            let p = AVAudioPlayerNode(), v = AVAudioUnitVarispeed()
            engine.attach(p)
            engine.attach(v)
            engine.connect(p, to: v, format: format)
            engine.connect(v, to: engine.mainMixerNode, format: format)
            voices.append((p, v))
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        start()
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { _ in
            Task { @MainActor in Sound.shared.start() }
        }
    }

    private func start() {
        guard !engine.isRunning else { running = true; return }
        engine.prepare()
        running = (try? engine.start()) != nil
    }

    static func play(_ s: SFX, pitch: Float = 1) { shared.play(s, pitch: pitch) }

    /// `pitch` (0.5…2) shifts pitch and speed together; per-card signatures use it for their own voice.
    func play(_ s: SFX, pitch: Float = 1) {
        guard enabled, let buf = buffers[s] else { return }
        if !engine.isRunning { start() }
        guard running, !voices.isEmpty else { return }
        let v = voices[cursor % voices.count]
        cursor += 1
        v.speed.rate = max(0.5, min(2, pitch))
        v.player.stop()
        v.player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        v.player.play()
    }

    private static let rate = 22050

    private static func volume(_ s: SFX) -> Float {
        switch s {
        case .ui, .card: return 0.35
        case .whoosh: return 0.28
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
        case .whoosh:
            // Air swing: band of noise rising then falling.
            return gen(0.16) { t, p in noise() * 0.5 * sin(Double.pi * p) * (0.6 + 0.4 * sin(2 * Double.pi * (300 + 900 * p) * t)) }
        case .crack:
            // Sharp knuckle snap.
            return gen(0.09) { t, p in (noise() * 0.8 + sin(2 * Double.pi * 1800 * t) * 0.3) * pow(1 - p, 5) }
        case .thud:
            // Deep body blow.
            return gen(0.22) { t, p in (sin(2 * Double.pi * (90 - 40 * p) * t) * 1.0 + noise() * 0.25) * pow(1 - p, 2.5) }
        case .slap:
            return gen(0.1) { t, p in (noise() * 0.7 + chirp(t, 600, 250, 0.1) * 0.4) * pow(1 - p, 3.5) }
        case .zap:
            // Electric energy shot.
            return gen(0.25) { t, p in (sin(2 * Double.pi * 1400 * t) * (sin(2 * Double.pi * 60 * t) > 0 ? 0.5 : -0.5) + noise() * 0.2) * pow(1 - p, 1.8) }
        case .boom:
            // Heavy energy cannon.
            return gen(0.45) { t, p in (chirp(t, 260, 50, 0.45) * 0.8 + noise() * 0.45) * pow(1 - p, 1.4) }
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
