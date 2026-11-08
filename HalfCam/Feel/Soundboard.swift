import AVFoundation

final class Soundboard {
    static let shared = Soundboard()
    var enabled = true
    private var players: [String: AVAudioPlayer] = [:]
    private var ticks: [AVAudioPlayer] = []
    private var tickIndex = 0

    func preload() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let names = ["shutter", "empty", "wind", "tick", "back", "rewind", "water", "reveal"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
            guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[name] = player
        }
        if let url = Bundle.main.url(forResource: "tick", withExtension: "wav") {
            for _ in 0..<4 {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    ticks.append(player)
                }
            }
        }
        players["rewind"]?.numberOfLoops = -1
        players["water"]?.numberOfLoops = -1
    }

    func play(_ name: String) {
        guard enabled else { return }
        if name == "tick" {
            guard !ticks.isEmpty else { return }
            let player = ticks[tickIndex % ticks.count]
            tickIndex += 1
            player.currentTime = 0
            player.play()
            return
        }
        guard let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }

    func stop(_ name: String) {
        players[name]?.stop()
        players[name]?.currentTime = 0
    }
}
