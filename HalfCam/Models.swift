import Foundation

enum AppConst {
    static let capacity = 36
    static let tutorialCapacity = 2
    static let tutorialWaitSeconds: TimeInterval = 5
    static let advanceRadians: Double = .pi * 2
    static let capacities = [12, 24, 36, 54, 72]

    static func monthlySkipGrant(_ tier: MembershipTier) -> Int {
        switch tier {
        case .free: 1
        case .yearly: 3
        case .lifetime: 6
        }
    }

    static func waitRange(capacity: Int) -> ClosedRange<Int> {
        switch capacity {
        case 12: 8...16
        case 24: 12...22
        case 36: 18...30
        case 54: 22...36
        default: 28...44
        }
    }

    static func waitMinutes(capacity: Int, seed: Int64) -> Int {
        let range = waitRange(capacity: capacity)
        var rng = SeededRandom(UInt64(bitPattern: seed) ^ 0xD1)
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + Int(rng.unit() * Double(span))
    }

    static func waitDuration(capacity: Int, seed: Int64, tutorial: Bool) -> TimeInterval {
        if tutorial { return tutorialWaitSeconds }
        return TimeInterval(waitMinutes(capacity: capacity, seed: seed) * 60)
    }

    static func monthlyLimit(_ tier: MembershipTier) -> Int? {
        switch tier {
        case .free: 3
        case .yearly: 9
        case .lifetime: nil
        }
    }

    static func allowedCapacities(_ tier: MembershipTier) -> [Int] {
        switch tier {
        case .free: [12]
        case .yearly: [12, 24, 36]
        case .lifetime: capacities
        }
    }

    static func monthStamp(_ date: Date = .now) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }
}

enum MembershipTier: String, CaseIterable, Identifiable, Codable {
    case free, yearly, lifetime
    var id: String { rawValue }
    var title: String {
        switch self {
        case .free: L("免费")
        case .yearly: L("年卡")
        case .lifetime: L("买断")
        }
    }
}

enum RollState: String, Codable {
    case shooting
    case needsRewind
    case canDevelop
    case waiting
    case developing
    case ready
}

enum GrainLevel: String, Codable, CaseIterable, Identifiable {
    case off, fine, medium, coarse, random
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: L("无")
        case .fine: L("细")
        case .medium: L("中")
        case .coarse: L("粗")
        case .random: L("随机")
        }
    }
    var amount: Float {
        switch self {
        case .off: 0
        case .fine: 0.45
        case .medium: 0.90
        case .coarse: 1.50
        case .random: 0
        }
    }

    func resolvedAmount(seed: Int64, frame: Int) -> Float {
        let base: Float
        if self == .random {
            var rng = SeededRandom(UInt64(bitPattern: seed) ^ 0x6F)
            let u = rng.unit()
            base = u < 0.30 ? GrainLevel.fine.amount : (u < 0.75 ? GrainLevel.medium.amount : GrainLevel.coarse.amount)
        } else {
            base = amount
        }
        guard base > 0 else { return 0 }
        var jitter = SeededRandom(UInt64(bitPattern: seed) &+ UInt64(frame) &* 17)
        return base * jitter.float(0.85, 1.15)
    }

    func resolvedSize(recipeSize: Float, seed: Int64, frame: Int) -> Float {
        var jitter = SeededRandom(UInt64(bitPattern: seed) &+ UInt64(frame) &* 31)
        return recipeSize * jitter.float(0.90, 1.10)
    }
}

enum DiffusionLevel: String, Codable, CaseIterable, Identifiable {
    case off, weak, strong
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: L("关")
        case .weak: L("弱")
        case .strong: L("强")
        }
    }
}

enum LeakLevel: String, Codable, CaseIterable, Identifiable {
    case off, occasional, wild
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: L("关")
        case .occasional: L("偶发")
        case .wild: L("任性")
        }
    }
    var probability: Double {
        switch self {
        case .off: 0
        case .occasional: 0.18
        case .wild: 0.55
        }
    }
}

struct Frame: Codable, Identifiable, Hashable {
    var id: UUID
    var index: Int
    var shotAt: Date
    var fileName: String
    var posFileName: String?
    var thumbFileName: String?
    var leakStrength: Float
    var leakAngle: Float
    var leakHue: Float
    var developed: Bool
    var exported: Bool
    var exportedAssetIds: [String]
    var exportedPairAssetIds: [String]
    var iso: Float?
    var shutter: Double?
    var lens: Float?

    enum CodingKeys: String, CodingKey {
        case id, index, shotAt, fileName, posFileName, thumbFileName
        case leakStrength, leakAngle, leakHue, developed, exported, exportedAssetIds, exportedPairAssetIds, iso, shutter, lens
    }

    init(
        id: UUID, index: Int, shotAt: Date, fileName: String,
        posFileName: String?, thumbFileName: String? = nil,
        leakStrength: Float, leakAngle: Float, leakHue: Float, developed: Bool,
        exported: Bool = false,
        exportedAssetIds: [String] = [],
        exportedPairAssetIds: [String] = [],
        iso: Float? = nil, shutter: Double? = nil, lens: Float? = nil
    ) {
        self.id = id
        self.index = index
        self.shotAt = shotAt
        self.fileName = fileName
        self.posFileName = posFileName
        self.thumbFileName = thumbFileName
        self.leakStrength = leakStrength
        self.leakAngle = leakAngle
        self.leakHue = leakHue
        self.developed = developed
        self.exported = exported
        self.exportedAssetIds = exportedAssetIds
        self.exportedPairAssetIds = exportedPairAssetIds
        self.iso = iso
        self.shutter = shutter
        self.lens = lens
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        index = try c.decode(Int.self, forKey: .index)
        shotAt = try c.decode(Date.self, forKey: .shotAt)
        fileName = try c.decode(String.self, forKey: .fileName)
        posFileName = try c.decodeIfPresent(String.self, forKey: .posFileName)
        thumbFileName = try c.decodeIfPresent(String.self, forKey: .thumbFileName)
        leakStrength = try c.decode(Float.self, forKey: .leakStrength)
        leakAngle = try c.decode(Float.self, forKey: .leakAngle)
        leakHue = try c.decode(Float.self, forKey: .leakHue)
        developed = try c.decode(Bool.self, forKey: .developed)
        exported = try c.decodeIfPresent(Bool.self, forKey: .exported) ?? false
        exportedAssetIds = try c.decodeIfPresent([String].self, forKey: .exportedAssetIds) ?? []
        exportedPairAssetIds = try c.decodeIfPresent([String].self, forKey: .exportedPairAssetIds) ?? []
        iso = try c.decodeIfPresent(Float.self, forKey: .iso)
        shutter = try c.decodeIfPresent(Double.self, forKey: .shutter)
        lens = try c.decodeIfPresent(Float.self, forKey: .lens)
    }
}

struct Roll: Codable, Identifiable, Hashable {
    var id: UUID
    var filmId: String
    var iso: Int
    var capacity: Int
    var shotCount: Int
    var state: RollState
    var grain: GrainLevel
    var leak: LeakLevel
    var diffusion: DiffusionLevel
    var dateStamp: Bool
    var paperId: String
    var cameraFilter: String
    var rollSeed: Int64
    var loadedAt: Date
    var rewindAt: Date?
    var developedAt: Date?
    var developReadyAt: Date?
    var leaderConsumed: Bool
    var armed: Bool
    var frames: [Frame]
    var isTutorial: Bool

    var remaining: Int { max(0, capacity - shotCount) }
    var isFull: Bool { shotCount >= capacity }
    var progress: Double { Double(shotCount) / Double(max(1, capacity)) }
    var canWind: Bool { state == .shooting && !armed && !isFull }
    var canShoot: Bool { state == .shooting && armed && !isFull }
    var waitRemaining: TimeInterval {
        guard let developReadyAt else { return 0 }
        return max(0, developReadyAt.timeIntervalSinceNow)
    }
    var isWaitReady: Bool { state == .waiting && waitRemaining <= 0 }

    enum CodingKeys: String, CodingKey {
        case id, filmId, iso, capacity, shotCount, state, grain, leak, diffusion, dateStamp
        case paperId, cameraFilter
        case rollSeed, loadedAt, rewindAt, developedAt, developReadyAt, leaderConsumed, armed, frames
        case isTutorial
    }

    init(
        id: UUID, filmId: String, iso: Int, capacity: Int, shotCount: Int, state: RollState,
        grain: GrainLevel, leak: LeakLevel, diffusion: DiffusionLevel, dateStamp: Bool,
        paperId: String = "", cameraFilter: String = "",
        rollSeed: Int64, loadedAt: Date, rewindAt: Date?, developedAt: Date?,
        developReadyAt: Date? = nil,
        leaderConsumed: Bool, armed: Bool, frames: [Frame],
        isTutorial: Bool = false
    ) {
        self.id = id
        self.filmId = filmId
        self.iso = iso
        self.capacity = capacity
        self.shotCount = shotCount
        self.state = state
        self.grain = grain
        self.leak = leak
        self.diffusion = diffusion
        self.dateStamp = dateStamp
        self.paperId = paperId
        self.cameraFilter = cameraFilter
        self.rollSeed = rollSeed
        self.loadedAt = loadedAt
        self.rewindAt = rewindAt
        self.developedAt = developedAt
        self.developReadyAt = developReadyAt
        self.leaderConsumed = leaderConsumed
        self.armed = armed
        self.frames = frames
        self.isTutorial = isTutorial
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        filmId = try c.decode(String.self, forKey: .filmId)
        iso = try c.decode(Int.self, forKey: .iso)
        capacity = try c.decode(Int.self, forKey: .capacity)
        shotCount = try c.decode(Int.self, forKey: .shotCount)
        state = try c.decode(RollState.self, forKey: .state)
        grain = try c.decode(GrainLevel.self, forKey: .grain)
        leak = try c.decode(LeakLevel.self, forKey: .leak)
        diffusion = try c.decodeIfPresent(DiffusionLevel.self, forKey: .diffusion) ?? .off
        dateStamp = try c.decode(Bool.self, forKey: .dateStamp)
        paperId = try c.decodeIfPresent(String.self, forKey: .paperId) ?? ""
        cameraFilter = try c.decodeIfPresent(String.self, forKey: .cameraFilter) ?? ""
        rollSeed = try c.decode(Int64.self, forKey: .rollSeed)
        loadedAt = try c.decode(Date.self, forKey: .loadedAt)
        rewindAt = try c.decodeIfPresent(Date.self, forKey: .rewindAt)
        developedAt = try c.decodeIfPresent(Date.self, forKey: .developedAt)
        developReadyAt = try c.decodeIfPresent(Date.self, forKey: .developReadyAt)
        leaderConsumed = try c.decode(Bool.self, forKey: .leaderConsumed)
        armed = try c.decode(Bool.self, forKey: .armed)
        frames = try c.decode([Frame].self, forKey: .frames)
        isTutorial = try c.decodeIfPresent(Bool.self, forKey: .isTutorial) ?? false
    }
}

struct SeededRandom {
    var state: UInt64
    init(_ seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double {
        Double(next() % 1_000_000) / 1_000_000
    }
    mutating func float(_ a: Float, _ b: Float) -> Float {
        a + Float(unit()) * (b - a)
    }
}

enum FocusStop: Int, Codable, CaseIterable, Identifiable {
    case near, meter, three, inf
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .near: "0.5m"
        case .meter: "1m"
        case .three: "3m"
        case .inf: "∞"
        }
    }
    var lens: Float {
        switch self {
        case .near: 0.15
        case .meter: 0.40
        case .three: 0.70
        case .inf: 1.0
        }
    }
}

enum ISOStop: Int, CaseIterable, Identifiable {
    case iso50 = 50
    case iso100 = 100
    case iso200 = 200
    case iso400 = 400
    case iso800 = 800
    case iso1600 = 1600
    case iso3200 = 3200
    var id: Int { rawValue }
    var title: String { "\(rawValue)" }
}

enum ShutterSpeed: Int, Codable, CaseIterable, Identifiable {
    case s1, s2, s4, s8, s15, s30, s60, s125, s250, s500, s1000
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .s1: "1"
        case .s2: "2"
        case .s4: "4"
        case .s8: "8"
        case .s15: "15"
        case .s30: "30"
        case .s60: "60"
        case .s125: "125"
        case .s250: "250"
        case .s500: "500"
        case .s1000: "1000"
        }
    }
    var denominator: Int32 {
        switch self {
        case .s1: 1
        case .s2: 2
        case .s4: 4
        case .s8: 8
        case .s15: 15
        case .s30: 30
        case .s60: 60
        case .s125: 125
        case .s250: 250
        case .s500: 500
        case .s1000: 1000
        }
    }
}

struct PersistStore: Codable {
    var rolls: [Roll]
    var currentRollId: UUID?
    var flashOn: Bool
    var soundOn: Bool
    var hapticOn: Bool
    var proRAW: Bool?
    var hasSeenHint: Bool
    var hasSeenBlackHint: Bool?
    var hasSeenDarkboxHint: Bool?
    var hasSeenAlbumHint: Bool?
    var hasSeenEVHint: Bool?
    var hasSeenFlashHint: Bool?
    var hasSeenManualHint: Bool?
    var hasSeenRewindHint: Bool?
    var hasSeenExportHint: Bool?
    var hasSeenKeepHint: Bool?
    var autoExportPrints: Bool?
    var exportFilmBorder: Bool?
    var manualMode: Bool?
    var strictMode: Bool?
    var hasCompletedOnboarding: Bool?
    var tutorialMaskDismissed: Bool?
    var lensLock: Bool? = nil
    var autoMacro: Bool? = nil
    var loadsThisMonth: Int?
    var loadMonthStamp: String?
    var skipTickets: Int? = nil
    var skipGranted: Int? = nil
    var skipPurchased: Int? = nil
    var skipGrantQuota: Int? = nil
    var skipCloudUpdatedAt: TimeInterval? = nil
}

struct SkipCloudLedger: Codable {
    var skipPurchased: Int
    var skipGranted: Int
    var skipGrantQuota: Int
    var loadMonthStamp: String
    var updatedAt: TimeInterval
}
