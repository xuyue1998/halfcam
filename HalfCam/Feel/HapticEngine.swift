import CoreHaptics
import UIKit

final class Haptics {
    static let shared = Haptics()
    var enabled = true

    private var engine: CHHapticEngine?
    private var supportsCH = false
    private var engineRunning = false
    private var players: [CHHapticPatternPlayer] = []
    private var grainPlayer: CHHapticAdvancedPatternPlayer?
    private var soakPlayer: CHHapticAdvancedPatternPlayer?
    private var grainTask: Task<Void, Never>?
    private var grainFade: Task<Void, Never>?
    private var lastToothAt: CFTimeInterval = 0
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let light = UIImpactFeedbackGenerator(style: .soft)

    static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    func prepare() {
        impact.prepare()
        light.prepare()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsCH = false
            engineRunning = false
            engine = nil
            return
        }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.resetHandler = { [weak self] in
                DispatchQueue.main.async {
                    self?.clearPlayers()
                    self?.engineRunning = false
                    self?.ensureRunning()
                }
            }
            engine.stoppedHandler = { [weak self] reason in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.clearPlayers()
                    self.engineRunning = false
                    if reason == .engineDestroyed {
                        self.engine = nil
                        self.supportsCH = false
                    }
                }
            }
            try engine.start()
            self.engine = engine
            supportsCH = true
            engineRunning = true
        } catch {
            engine = nil
            supportsCH = false
            engineRunning = false
        }
    }

    func resume() {
        impact.prepare()
        light.prepare()
        if engine == nil {
            prepare()
            return
        }
        ensureRunning()
    }

    func chrome() {
        guard enabled else { return }
        play(events: [transient(0.16, 0.38)], fallback: light, intensity: 0.16)
    }

    func tick() {
        guard enabled else { return }
        play(events: [transient(0.12, 0.32)], fallback: light, intensity: 0.12)
    }

    func tooth(speed: CGFloat) {
        guard enabled else { return }
        let now = CACurrentMediaTime()
        if now - lastToothAt < 0.018 { return }
        lastToothAt = now
        let t = Float(min(max(speed / 12, 0), 1))
        let intensity = 0.18 + t * 0.37
        play(events: [transient(intensity, 0.88 + t * 0.08)], fallback: light, intensity: CGFloat(intensity))
    }

    func detent(zero: Bool = false) {
        guard enabled else { return }
        if zero {
            play(events: [transient(0.58, 0.52)], fallback: impact, intensity: 0.62)
        } else {
            play(events: [transient(0.38, 0.72)], fallback: light, intensity: 0.38)
        }
    }

    func latch() {
        guard enabled else { return }
        play(
            events: [
                transient(0.28, 0.32),
                continuous(0.22, 0.18, 0.04, 0.006)
            ],
            fallback: light,
            intensity: 0.28
        )
    }

    func thud() {
        guard enabled else { return }
        play(events: [continuous(0.62, 0.18, 0.04)], fallback: impact, intensity: 0.55)
    }

    func focus() {
        guard enabled else { return }
        play(events: [transient(0.14, 0.36)], fallback: light, intensity: 0.14)
    }

    func advance() {
        guard enabled else { return }
        play(
            events: [
                transient(0.70, 0.95),
                continuous(1.0, 0.38, 0.08, 0.026)
            ],
            fallback: impact,
            intensity: 1.0
        )
    }

    func shutter() {
        guard enabled else { return }
        impact.impactOccurred(intensity: 1.0)
        play(
            events: [
                transient(1.0, 0.95),
                transient(0.82, 0.42, 0.018)
            ],
            fallback: impact,
            intensity: 1.0
        )
    }

    func empty() {
        guard enabled else { return }
        play(
            events: [
                transient(0.38, 0.16),
                continuous(0.18, 0.10, 0.045, 0.006)
            ],
            fallback: light,
            intensity: 0.25
        )
    }

    func grainStart(duration: TimeInterval = 1.6) {
        guard enabled else { return }
        grainStop(fade: false)
        if supportsCH, ensureRunning(), let engine {
            let event = continuous(1.0, 0.55, duration)
            let intensity = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.55),
                    .init(relativeTime: duration * 0.35, value: 0.38),
                    .init(relativeTime: duration, value: 0.12)
                ],
                relativeTime: 0
            )
            let sharpness = CHHapticParameterCurve(
                parameterID: .hapticSharpnessControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.55),
                    .init(relativeTime: duration * 0.4, value: 0.32),
                    .init(relativeTime: duration, value: 0.12)
                ],
                relativeTime: 0
            )
            if let pattern = try? CHHapticPattern(events: [event], parameterCurves: [intensity, sharpness]),
               let player = try? engine.makeAdvancedPlayer(with: pattern) {
                grainPlayer = player
                try? player.start(atTime: 0)
                return
            }
        }
        grainTask = Task { @MainActor in
            let start = Date()
            while !Task.isCancelled {
                let p = Date().timeIntervalSince(start) / duration
                if p >= 1 { break }
                let i = 0.55 * (1 - p) + 0.12 * p
                light.impactOccurred(intensity: i)
                try? await Task.sleep(for: .milliseconds(140))
            }
        }
    }

    func grainStop(fade: Bool = true) {
        grainTask?.cancel()
        grainTask = nil
        grainFade?.cancel()
        guard let player = grainPlayer else { return }
        if fade, supportsCH {
            let drop = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0, relativeTime: 0)
            try? player.sendParameters([drop], atTime: 0)
            grainFade = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                try? player.stop(atTime: 0)
                if grainPlayer === player { grainPlayer = nil }
            }
            return
        }
        try? player.stop(atTime: 0)
        grainPlayer = nil
    }

    func soakStart(duration: TimeInterval = 60) {
        guard enabled else { return }
        soakStop()
        if supportsCH, ensureRunning(), let engine {
            let event = continuous(1.0, 0.08, duration)
            let curve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.12),
                    .init(relativeTime: min(4, duration), value: 0.22),
                    .init(relativeTime: duration, value: 0.14)
                ],
                relativeTime: 0
            )
            if let pattern = try? CHHapticPattern(events: [event], parameterCurves: [curve]),
               let player = try? engine.makeAdvancedPlayer(with: pattern) {
                soakPlayer = player
                try? player.start(atTime: 0)
            }
        }
    }

    func soakBubble() {
        guard enabled else { return }
        play(events: [transient(0.22, 0.18)], fallback: light, intensity: 0.18)
    }

    func soakStop() {
        try? soakPlayer?.stop(atTime: 0)
        soakPlayer = nil
    }

    func swell() {
        guard enabled else { return }
        let duration: TimeInterval = 0.22
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.25),
                .init(relativeTime: 0.08, value: 0.78),
                .init(relativeTime: duration, value: 0)
            ],
            relativeTime: 0
        )
        play(events: [continuous(1.0, 0.22, duration)], curves: [curve], fallback: impact, intensity: 0.55)
    }

    func pair() {
        guard enabled else { return }
        play(events: [transient(0.28, 0.55)], fallback: light, intensity: 0.28)
    }

    private func clearPlayers() {
        grainFade?.cancel()
        grainFade = nil
        try? grainPlayer?.stop(atTime: 0)
        grainPlayer = nil
        try? soakPlayer?.stop(atTime: 0)
        soakPlayer = nil
        for player in players { try? player.stop(atTime: 0) }
        players.removeAll()
    }

    private func transient(_ intensity: Float, _ sharpness: Float, _ time: TimeInterval = 0) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: clamp(intensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: clamp(sharpness))
            ],
            relativeTime: time
        )
    }

    private func continuous(_ intensity: Float, _ sharpness: Float, _ duration: TimeInterval, _ time: TimeInterval = 0) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: clamp(intensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: clamp(sharpness))
            ],
            relativeTime: time,
            duration: duration
        )
    }

    @discardableResult
    private func ensureRunning() -> Bool {
        guard supportsCH, let engine else { return false }
        if engineRunning { return true }
        do {
            try engine.start()
            engineRunning = true
            return true
        } catch {
            engineRunning = false
            return false
        }
    }

    private func play(
        events: [CHHapticEvent],
        curves: [CHHapticParameterCurve] = [],
        fallback generator: UIImpactFeedbackGenerator? = nil,
        intensity: CGFloat = 0.18
    ) {
        guard supportsCH, ensureRunning(), let engine else {
            if let generator { fallback(generator, intensity) }
            return
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            if players.count >= 8 {
                let old = players.removeFirst()
                try? old.stop(atTime: CHHapticTimeImmediate)
            }
            players.append(player)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            engineRunning = false
            players.removeAll()
            if let generator { fallback(generator, intensity) }
        }
    }

    private func fallback(_ generator: UIImpactFeedbackGenerator, _ intensity: CGFloat) {
        guard !supportsCH || !engineRunning else { return }
        generator.impactOccurred(intensity: min(1, max(0.01, intensity)))
    }

    private func clamp(_ value: Float) -> Float {
        min(1, max(0, value))
    }
}
