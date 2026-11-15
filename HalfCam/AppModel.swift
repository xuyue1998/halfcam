import AVFoundation
import CoreImage
import Foundation
import ImageIO
import Observation
import Photos
import UIKit

final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()

    private let previews = NSCache<NSString, UIImage>()
    private let displays = NSCache<NSString, UIImage>()
    private let negatives = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var inflight: [String: Inflight] = [:]
    private let ci = CIContext(options: [.cacheIntermediates: false])

    private init() {
        previews.countLimit = 80
        previews.totalCostLimit = 32 * 1024 * 1024
        displays.countLimit = 16
        displays.totalCostLimit = 64 * 1024 * 1024
        negatives.countLimit = 40
        negatives.totalCostLimit = 16 * 1024 * 1024
    }

    func preview(_ key: String) -> UIImage? { previews.object(forKey: key as NSString) }
    func display(_ key: String) -> UIImage? { displays.object(forKey: key as NSString) }
    func negative(_ key: String) -> UIImage? { negatives.object(forKey: key as NSString) }

    private var previewKeys = Set<String>()
    private var displayKeys = Set<String>()
    private var negativeKeys = Set<String>()

    func purge() {
        lock.lock()
        inflight.removeAll()
        previewKeys.removeAll()
        displayKeys.removeAll()
        negativeKeys.removeAll()
        lock.unlock()
        previews.removeAllObjects()
        displays.removeAllObjects()
        negatives.removeAllObjects()
    }

    func purge(prefix: String) {
        lock.lock()
        let p = previewKeys.filter { $0.hasPrefix(prefix) }
        let d = displayKeys.filter { $0.hasPrefix(prefix) }
        let n = negativeKeys.filter { $0.hasPrefix(prefix) }
        previewKeys.subtract(p)
        displayKeys.subtract(d)
        negativeKeys.subtract(n)
        let flying = inflight.keys.filter { $0.hasSuffix(prefix) || $0.contains(prefix) }
        for key in flying { inflight.removeValue(forKey: key) }
        lock.unlock()
        for key in p { previews.removeObject(forKey: key as NSString) }
        for key in d { displays.removeObject(forKey: key as NSString) }
        for key in n { negatives.removeObject(forKey: key as NSString) }
    }

    func loadPreview(key: String, url: URL, priority: TaskPriority = .userInitiated) async -> UIImage? {
        if let hit = preview(key) { return hit }
        return await coalesce("p:" + key, priority: priority) {
            if let hit = self.preview(key) { return hit }
            let disk = Self.previewDiskURL(for: url)
            if FileManager.default.fileExists(atPath: disk.path),
               let img = Self.decode(disk, maxSide: 360) {
                self.remember(.preview, key: key, image: img)
                return img
            }
            guard let img = Self.decode(url, maxSide: 360) else { return nil }
            self.remember(.preview, key: key, image: img)
            Self.writePreviewDisk(img, to: disk)
            return img
        }
    }

    func loadDisplay(key: String, url: URL) async -> UIImage? {
        if let hit = display(key) { return hit }
        return await coalesce("d:" + key) {
            if let hit = self.display(key) { return hit }
            guard let img = Self.decode(url, maxSide: 1200) else { return nil }
            self.remember(.display, key: key, image: img)
            return img
        }
    }

    func loadNegative(key: String, url: URL) async -> UIImage? {
        if let hit = negative(key) { return hit }
        return await coalesce("n:" + key) {
            if let hit = self.negative(key) { return hit }
            guard let pos = Self.decode(url, maxSide: 360), let ciImg = CIImage(image: pos) else { return nil }
            let inverted = ciImg.applyingFilter("CIColorInvert")
            let hue = inverted.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: -0.49])
            let mapped = hue.applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0.72,
                    kCIInputContrastKey: 1.05
                ]
            )
            guard let cg = self.ci.createCGImage(mapped, from: mapped.extent) else { return nil }
            let img = UIImage(cgImage: cg)
            self.remember(.negative, key: key, image: img)
            return img
        }
    }

    private struct Inflight {
        let gen: Int
        let task: Task<UIImage?, Never>
        let priority: TaskPriority
        var waiters: Int
    }

    private enum CacheKind { case preview, display, negative }

    private func remember(_ kind: CacheKind, key: String, image: UIImage) {
        lock.lock()
        switch kind {
        case .preview: previewKeys.insert(key)
        case .display: displayKeys.insert(key)
        case .negative: negativeKeys.insert(key)
        }
        lock.unlock()
        switch kind {
        case .preview: previews.setObject(image, forKey: key as NSString, cost: Self.cost(image))
        case .display: displays.setObject(image, forKey: key as NSString, cost: Self.cost(image))
        case .negative: negatives.setObject(image, forKey: key as NSString, cost: Self.cost(image))
        }
    }

    private func coalesce(
        _ key: String,
        priority: TaskPriority = .userInitiated,
        work: @escaping @Sendable () async -> UIImage?
    ) async -> UIImage? {
        let started = start(key, priority: priority, work: work)
        let img = await started.task.value
        end(key, gen: started.gen)
        return img
    }

    private func start(
        _ key: String,
        priority: TaskPriority,
        work: @escaping @Sendable () async -> UIImage?
    ) -> Inflight {
        lock.lock()
        defer { lock.unlock() }
        if let existing = inflight[key], existing.priority >= priority {
            inflight[key]?.waiters += 1
            return inflight[key]!
        }
        let task = Task.detached(priority: priority, operation: work)
        let gen = (inflight[key]?.gen ?? 0) + 1
        let entry = Inflight(gen: gen, task: task, priority: priority, waiters: 1)
        inflight[key] = entry
        return entry
    }

    private static func previewDiskURL(for url: URL) -> URL {
        URL(fileURLWithPath: url.path + ".p360.jpg")
    }

    private static func writePreviewDisk(_ image: UIImage, to url: URL) {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func end(_ key: String, gen: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard inflight[key]?.gen == gen else { return }
        inflight[key]?.waiters -= 1
        if inflight[key]?.waiters == 0 {
            inflight.removeValue(forKey: key)
        }
    }

    static func decodeExport(_ url: URL, maxSide: CGFloat) -> UIImage? {
        decode(url, maxSide: maxSide)
    }

    private static func decode(_ url: URL, maxSide: CGFloat) -> UIImage? {
        let srcOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxSide)
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func cost(_ image: UIImage) -> Int {
        let w = Int(image.size.width * image.scale)
        let h = Int(image.size.height * image.scale)
        return max(1, w * h * 4)
    }
}

@Observable
@MainActor
final class AppModel {
    var rolls: [Roll] = []
    var currentRollId: UUID?
    var flashOn = false
    var soundOn = true
    var hapticOn = true
    var strictMode = true
    var hasSeenHint = false
    var hasSeenBlackHint = false
    var hasSeenDarkboxHint = false
    var hasSeenAlbumHint = false
    var hasSeenEVHint = false
    var hasSeenFlashHint = false
    var hasSeenManualHint = false
    var hasSeenRewindHint = false
    var hasSeenExportHint = false
    var hasSeenKeepHint = false
    var autoExportPrints = true
    var exportFilmBorder = true
    var exportBusy = false
    var exportNotice = ""
    var hasCompletedOnboarding = false
    var tutorialMaskDismissed = false
    var autoMacro = true
    var pendingLoadRoll = false
    var showPaywall = false
    var presentingLoadRoll = false
    var loadsThisMonth = 0
    var loadMonthStamp = ""
    var skipGranted = 0
    var skipPurchased = 0
    var skipGrantQuota = 0
    private var skipCloudUpdatedAt: TimeInterval = 0
    private var skipCloudReady = false

    var skipTickets: Int { skipGranted + skipPurchased }
    let membership = Entitlements.shared
    var pipelineRunning = false
    private var developQueue: [UUID] = []
    var manualMode = false
    var shutterAuto = true
    var isoAuto = true
    var isoValue: Int = 400
    var focusAuto = true
    var shutter: ShutterSpeed = .s125
    var aperture: Float?
    var focusLens: Float = 1
    var ev: Float = 0
    var showDarkbox = false
    var showAlbum = false
    var showDarkroom = false
    var showSettings = false
    var language: AppLanguage = L10n.shared.language {
        didSet {
            guard language != oldValue else { return }
            L10n.shared.language = language
        }
    }
    var handoffToast = ""
    var pendingDevelopId: UUID?
    var ritualRollId: UUID?
    var isCapturing = false
    var developProgress: Double = 0
    var camera = CameraSession()
    var proRAW = false
    private var pendingWrites = 0
    private var persistTask: Task<Void, Never>?
    private var coverWarmup: Task<Void, Never>?
    private var coverWarmupPriority: TaskPriority?

    var currentRoll: Roll? {
        get {
            guard let currentRollId else { return nil }
            return rolls.first { $0.id == currentRollId }
        }
        set {
            guard let newValue else {
                currentRollId = nil
                persistSoon()
                return
            }
            upsert(newValue)
            currentRollId = newValue.id
            persistSoon()
        }
    }

    var darkboxRolls: [Roll] {
        rolls.filter { $0.state != .ready }.sorted { $0.loadedAt > $1.loadedAt }
    }

    var albumRolls: [Roll] {
        rolls.filter { $0.state == .ready }.sorted { ($0.developedAt ?? $0.loadedAt) > ($1.developedAt ?? $1.loadedAt) }
    }

    var tier: MembershipTier { membership.tier }

    var monthlyLimit: Int? { AppConst.monthlyLimit(tier) }

    var canLoadRoll: Bool {
        guard let cap = monthlyLimit else { return true }
        return loadsThisMonth < cap
    }

    func canUseCapacity(_ n: Int) -> Bool {
        AppConst.allowedCapacities(tier).contains(n)
    }

    var defaultCapacity: Int {
        let allowed = AppConst.allowedCapacities(tier)
        if allowed.contains(36) { return 36 }
        return allowed.last ?? 12
    }

    var isOnboarding: Bool { !hasCompletedOnboarding }

    var tutorialDumpRollId: UUID? {
        guard isOnboarding else { return nil }
        return albumRolls.first(where: \.isTutorial)?.id
    }

    var tutorialInProgress: Bool {
        isOnboarding && rolls.contains { $0.isTutorial && $0.state != .ready }
    }

    var tutorialLocked: Bool {
        guard isOnboarding else { return false }
        if let roll = currentRoll { return roll.isTutorial }
        return tutorialInProgress || currentRollId == nil
    }

    var counterText: String {
        guard let roll = currentRoll else { return "--" }
        if !roll.leaderConsumed { return "00" }
        if roll.armed { return String(format: "%02d", min(roll.capacity, roll.shotCount + 1)) }
        return String(format: "%02d", roll.shotCount)
    }

    init() {
        load()
        listenSkipCloud()
        pullSkipCloud()
        membership.onSkipPackGranted = { [weak self] count in
            self?.addSkipTickets(count)
        }
        applyFeel()
        language = L10n.shared.language
        camera.start()
        Task { @MainActor in
            Soundboard.shared.preload()
            Haptics.shared.prepare()
        }
        DispatchQueue.global(qos: .utility).async {
            _ = SpektraEngine.shared.isAvailable
        }
        if let developing = rolls.first(where: { $0.state == .developing }) {
            ritualRollId = developing.id
            showDarkroom = true
            enqueueDevelop(developing.id)
        }
        for roll in rolls where roll.state == .waiting {
            enqueueDevelop(roll.id)
            if !roll.isTutorial, let ready = roll.developReadyAt {
                let film = FilmCatalog.recipe(id: roll.filmId)
                DevelopNotify.schedule(rollId: roll.id, filmName: film.name, at: ready)
            }
        }
        Task { await DevelopLive.sync(rolls: rolls) }
        rolloverMonth()
        if isOnboarding, currentRollId == nil, rolls.contains(where: { $0.isTutorial && $0.state != .ready }) {
            showDarkbox = true
        }
        if tutorialDumpRollId != nil {
            showAlbum = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            await warmupAlbumCovers()
        }
    }

    @discardableResult
    func rolloverMonth() -> Bool {
        let stamp = AppConst.monthStamp()
        let rolled = loadMonthStamp != stamp
        if rolled {
            loadMonthStamp = stamp
            loadsThisMonth = 0
            skipGranted = 0
            skipGrantQuota = 0
        }
        syncSkipGrant()
        if rolled { persistSoon() }
        pushSkipCloud()
        return rolled
    }

    func syncSkipGrant() {
        let quota = AppConst.monthlySkipGrant(tier)
        guard quota > skipGrantQuota else { return }
        skipGranted += quota - skipGrantQuota
        skipGrantQuota = quota
        persistSoon()
        pushSkipCloud()
    }

    func loadRoll(
        film: FilmRecipe,
        grain: GrainLevel,
        leak: LeakLevel,
        diffusion: DiffusionLevel = .off,
        dateStamp: Bool,
        paperId: String = "",
        cameraFilter: String = "",
        capacity: Int = AppConst.capacity,
        isTutorial: Bool = false
    ) {
        if !isTutorial {
            rolloverMonth()
            guard canLoadRoll, canUseCapacity(capacity) else { return }
        }
        let roll = Roll(
            id: UUID(),
            filmId: film.id,
            iso: film.iso,
            capacity: capacity,
            shotCount: 0,
            state: .shooting,
            grain: grain,
            leak: leak,
            diffusion: diffusion,
            dateStamp: dateStamp,
            paperId: paperId.isEmpty ? film.defaultPaperId : paperId,
            cameraFilter: cameraFilter,
            rollSeed: Int64.random(in: 1...9_000_000),
            loadedAt: Date(),
            rewindAt: nil,
            developedAt: nil,
            leaderConsumed: false,
            armed: false,
            frames: [],
            isTutorial: isTutorial
        )
        rolls.append(roll)
        currentRollId = roll.id
        isoValue = film.iso
        isoAuto = true
        let filmId = film.id
        let paper = roll.paperId
        DispatchQueue.global(qos: .utility).async {
            SpektraEngine.shared.warmUp(film: FilmCatalog.spkFilm(id: filmId), paper: paper)
        }
        if !isTutorial {
            loadsThisMonth += 1
        }
        Soundboard.shared.play("back")
        Haptics.shared.latch()
        applyExposureMode()
        persistNow()
    }

    func setManualMode(_ on: Bool) {
        manualMode = on
        if on {
            shutterAuto = true
            isoAuto = true
            isoValue = currentRoll?.iso ?? 400
            focusAuto = true
            aperture = nil
        }
        applyExposureMode()
        persistSoon()
    }

    func setShutterAuto() {
        shutterAuto = true
        applyExposureMode()
    }

    func setShutter(_ value: ShutterSpeed) {
        shutter = value
        shutterAuto = false
        applyExposureMode()
    }

    func setISOAuto() {
        isoAuto = true
        applyExposureMode()
    }

    func setISOManual() {
        isoAuto = false
        isoValue = currentRoll?.iso ?? isoValue
        applyExposureMode()
    }

    func setISO(_ value: Int) {
        isoValue = value
        isoAuto = false
        applyExposureMode()
    }

    func setAperture(_ value: Float) {
        aperture = value
        camera.setAperture(value)
    }

    func setFocusAuto() {
        focusAuto = true
        applyExposureMode()
    }

    func toggleFocusAuto() {
        if focusAuto {
            focusAuto = false
        } else {
            focusAuto = true
        }
        applyExposureMode()
    }

    func setFocusLens(_ value: Float) {
        focusLens = CameraSession.clampLens(value)
        let wasAuto = focusAuto
        focusAuto = false
        if wasAuto {
            applyExposureMode()
        }
        camera.setManualFocus(focusLens)
    }

    var focusDistanceLabel: String {
        if focusLens >= 0.97 { return "∞" }
        let d = CameraSession.focusDistance(slider: focusLens, minFocus: camera.currentMinFocusMeters)
        let n = CameraSession.formatFocus(d)
        return n == "∞" ? n : "\(n) m"
    }

    func setEV(_ value: Float, dragging: Bool = false) {
        ev = min(2, max(-2, value))
        if dragging {
            camera.setEV(ev)
            return
        }
        applyExposureMode()
    }

    func applyExposureMode() {
        camera.savedEV = ev
        let factor = powf(2, ev)
        let lockedISO = Float(isoValue)
        if !manualMode {
            if isoAuto {
                camera.applyAuto()
            } else {
                camera.applyMixed(shutter: nil, iso: lockedISO, evFactor: factor)
            }
            return
        }
        let lockedTime = CMTime(value: 1, timescale: shutter.denominator)
        let time: CMTime?
        let iso: Float?
        if shutterAuto && isoAuto {
            time = nil
            iso = nil
        } else if !shutterAuto && isoAuto {
            time = lockedTime
            iso = nil
        } else if shutterAuto && !isoAuto {
            time = nil
            iso = lockedISO
        } else {
            time = lockedTime
            iso = lockedISO
        }
        camera.applyMixed(shutter: time, iso: iso, evFactor: factor)
        if focusAuto {
            camera.unlockFocus()
        } else {
            camera.setManualFocus(focusLens)
        }
        if let aperture {
            camera.setAperture(aperture)
        }
    }

    func wind() {
        guard var roll = currentRoll, roll.canWind else { return }
        if !roll.leaderConsumed {
            roll.leaderConsumed = true
        }
        roll.armed = true
        currentRoll = roll
        Soundboard.shared.play("wind")
        Haptics.shared.advance()
        hasSeenHint = true
        persistNow()
    }

    func commitShot(_ data: Data) {
        guard var roll = currentRoll, roll.canShoot else { return }
        let index = roll.shotCount + 1
        let fileName = String(format: "%03d.neg", index)
        let dir = rollDir(roll.id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        writeFrameFile(url: dir.appendingPathComponent(fileName), data: data)
        let frame = Frame(
            id: UUID(),
            index: index,
            shotAt: Date(),
            fileName: fileName,
            posFileName: nil,
            thumbFileName: nil,
            leakStrength: 0,
            leakAngle: 0,
            leakHue: 0,
            developed: false,
            iso: camera.lastMeter.iso,
            shutter: camera.lastMeter.shutter,
            lens: camera.lastMeter.lens
        )
        roll.frames.append(frame)
        roll.shotCount = index
        roll.armed = false
        if roll.isFull {
            roll.state = .needsRewind
        }
        currentRoll = roll
        persistNow()
    }

    private func writeFrameFile(url: URL, data: Data) {
        pendingWrites += 1
        Task.detached(priority: .userInitiated) {
            try? data.write(to: url, options: [.atomic, .completeFileProtection])
            await MainActor.run { self.pendingWrites = max(0, self.pendingWrites - 1) }
        }
    }

    private func waitForWrites() async {
        let deadline = Date().addingTimeInterval(12)
        while pendingWrites > 0, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    func rewind() {
        guard var roll = currentRoll else { return }
        guard roll.state == .needsRewind || (roll.state == .shooting && roll.shotCount > 0) else { return }
        roll.state = .canDevelop
        roll.armed = false
        roll.rewindAt = Date()
        currentRoll = nil
        upsert(roll)
        pendingDevelopId = roll.id
        if !isOnboarding {
            showDarkbox = true
        }
        persistNow()
    }

    func forceUnload(ignoreStrict: Bool = false) {
        guard let roll = currentRoll else { return }
        if !ignoreStrict, strictMode, roll.shotCount > 0, !roll.isFull { return }
        if roll.shotCount == 0 {
            rolls.removeAll { $0.id == roll.id }
            try? FileManager.default.removeItem(at: rollDir(roll.id))
            currentRollId = nil
        } else {
            var r = roll
            r.state = .canDevelop
            r.armed = false
            r.rewindAt = Date()
            currentRollId = nil
            upsert(r)
            pendingDevelopId = r.id
            showDarkbox = true
        }
        persistNow()
    }

    func submitDevelop(_ id: UUID) {
        guard let idx = rolls.firstIndex(where: { $0.id == id }) else { return }
        guard rolls[idx].state == .canDevelop else { return }
        let tutorial = rolls[idx].isTutorial
        let wait = AppConst.waitDuration(
            capacity: rolls[idx].capacity,
            seed: rolls[idx].rollSeed,
            tutorial: tutorial
        )
        let ready = Date().addingTimeInterval(wait)
        rolls[idx].state = .waiting
        rolls[idx].developReadyAt = ready
        persistNow()
        enqueueDevelop(id)
        if tutorial {
            showDarkroom = false
            ritualRollId = nil
            showDarkbox = true
            handoffToast = L("已送进暗房 · 约 5 秒")
        } else {
            let film = FilmCatalog.recipe(id: rolls[idx].filmId)
            DevelopNotify.schedule(rollId: id, filmName: film.name, at: ready)
            ritualRollId = id
            showDarkroom = true
            Task { await DevelopLive.sync(rolls: rolls) }
            Task {
                let delay = ready.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                await DevelopLive.sync(rolls: self.rolls)
            }
        }
    }

    func finishHandoff() {
        let seconds: TimeInterval = {
            guard let id = ritualRollId,
                  let roll = rolls.first(where: { $0.id == id }),
                  let ready = roll.developReadyAt else { return 0 }
            return max(0, ready.timeIntervalSinceNow)
        }()
        showDarkroom = false
        ritualRollId = nil
        showDarkbox = true
        if seconds > 0 {
            if seconds < 60 {
                handoffToast = L("已送进暗房 · 约 \(Int(ceil(seconds))) 秒")
            } else {
                let minutes = max(1, Int(ceil(seconds / 60)))
                handoffToast = L("已送进暗房 · 约 \(minutes) 分钟")
            }
        }
        persistNow()
    }

    func collectDevelop(_ id: UUID) {
        guard let roll = rolls.first(where: { $0.id == id }) else { return }
        guard roll.state == .waiting, roll.isWaitReady else { return }
        presentRitual(id)
    }

    func addSkipTickets(_ count: Int) {
        guard count != 0 else { return }
        skipPurchased = max(0, skipPurchased + count)
        persistNow()
        pushSkipCloud()
    }

    func applySkipTicket(_ id: UUID) {
        guard skipTickets > 0 else { return }
        guard let idx = rolls.firstIndex(where: { $0.id == id }) else { return }
        guard rolls[idx].state == .waiting, !rolls[idx].isTutorial else { return }
        guard rolls[idx].waitRemaining > 0 else { return }
        if skipGranted > 0 {
            skipGranted -= 1
        } else {
            skipPurchased = max(0, skipPurchased - 1)
        }
        rolls[idx].developReadyAt = Date()
        persistNow()
        pushSkipCloud()
        let film = FilmCatalog.recipe(id: rolls[idx].filmId)
        DevelopNotify.schedule(rollId: id, filmName: film.name, at: rolls[idx].developReadyAt ?? Date())
        Task { await DevelopLive.sync(rolls: rolls) }
    }

    func resumeRitual(_ id: UUID) {
        guard rolls.contains(where: { $0.id == id && $0.state == .developing }) else { return }
        ritualRollId = id
        showDarkbox = false
        showDarkroom = true
        enqueueDevelop(id)
    }

    func presentRitual(_ id: UUID) {
        guard let idx = rolls.firstIndex(where: { $0.id == id }) else { return }
        rolls[idx].state = .developing
        ritualRollId = id
        developProgress = 0
        showDarkbox = false
        showDarkroom = true
        persistNow()
        DevelopNotify.cancel(rollId: id)
        Task { await DevelopLive.sync(rolls: rolls) }
        enqueueDevelop(id)
    }

    func openDarkboxFromNotify() {
        showAlbum = false
        showSettings = false
        showDarkbox = true
    }

    func refreshLiveActivities() {
        Task { await DevelopLive.sync(rolls: rolls) }
    }

    func finishRitual(loadNew: Bool = false, autoDump: Bool? = nil) {
        let dumpId = ritualRollId
        let tutorial: Bool = {
            guard let id = dumpId, let roll = rolls.first(where: { $0.id == id }) else { return false }
            return roll.isTutorial
        }()
        if let id = dumpId, let i = rolls.firstIndex(where: { $0.id == id }) {
            rolls[i].state = .ready
            rolls[i].developedAt = Date()
        }
        if isOnboarding, !tutorial {
            completeOnboarding()
        }
        Task { await DevelopLive.sync(rolls: rolls) }
        showDarkroom = false
        ritualRollId = nil
        showDarkbox = false
        if loadNew {
            showAlbum = false
            pendingLoadRoll = true
        } else {
            showAlbum = true
            if let id = dumpId, let roll = rolls.first(where: { $0.id == id }) {
                Task { await warmupCover(of: roll, priority: .userInitiated) }
            }
        }
        persistNow()
        let shouldDump = autoDump ?? autoExportPrints
        if shouldDump, !tutorial, let id = dumpId {
            Task {
                let outcome = await exportPrints(rollId: id)
                switch outcome {
                case .saved, .noPrints:
                    break
                case .noPermission, .failed:
                    flashExportNotice(PhotoExport.toast(outcome))
                }
            }
        }
    }

    func deleteAlbumRoll(_ id: UUID) {
        guard let roll = rolls.first(where: { $0.id == id }), roll.state == .ready else { return }
        rolls.removeAll { $0.id == id }
        ImageStore.shared.purge(prefix: id.uuidString)
        try? FileManager.default.removeItem(at: rollDir(id))
        persistNow()
    }

    func markExported(rollId: UUID, frameIds: [UUID], assetId: String? = nil, asPair: Bool = false) {
        guard let ri = rolls.firstIndex(where: { $0.id == rollId }) else { return }
        for id in frameIds {
            guard let fi = rolls[ri].frames.firstIndex(where: { $0.id == id }) else { continue }
            if asPair {
                if let assetId, !assetId.isEmpty,
                   !rolls[ri].frames[fi].exportedPairAssetIds.contains(assetId) {
                    rolls[ri].frames[fi].exportedPairAssetIds.append(assetId)
                }
            } else {
                rolls[ri].frames[fi].exported = true
                if let assetId, !assetId.isEmpty,
                   !rolls[ri].frames[fi].exportedAssetIds.contains(assetId) {
                    rolls[ri].frames[fi].exportedAssetIds.append(assetId)
                }
            }
        }
        persistSoon()
        completeOnboarding()
    }

    func isPairDumped(_ frames: [Frame]) -> Bool {
        let ready = frames.filter { $0.developed && $0.posFileName != nil }
        guard !ready.isEmpty else { return false }
        if ready.count == 1 { return ready[0].exported }
        return ready.allSatisfy { !$0.exportedPairAssetIds.isEmpty }
    }

    func unexportedDumpGroups(in roll: Roll) -> [[Frame]] {
        filmPairs(roll.frames).filter { pair in
            let ready = pair.filter { $0.developed && $0.posFileName != nil }
            guard !ready.isEmpty else { return false }
            return !isPairDumped(ready)
        }
    }

    func dumpGroupCount(in roll: Roll) -> Int {
        filmPairs(roll.frames).filter { pair in
            pair.contains { $0.developed && $0.posFileName != nil }
        }.count
    }

    func reconcileExportedPrints() async {
        let ids = rolls.flatMap { roll in
            roll.frames.flatMap { $0.exportedAssetIds + $0.exportedPairAssetIds }
        }
        guard !ids.isEmpty else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        let live = await Task.detached(priority: .utility) {
            PhotoExport.liveAssetIds(ids)
        }.value
        var changed = false
        for ri in rolls.indices {
            for fi in rolls[ri].frames.indices {
                let singles = rolls[ri].frames[fi].exportedAssetIds
                if !singles.isEmpty {
                    let kept = singles.filter { live.contains($0) }
                    if kept.isEmpty {
                        rolls[ri].frames[fi].exported = false
                        rolls[ri].frames[fi].exportedAssetIds = []
                        changed = true
                    } else if kept.count != singles.count {
                        rolls[ri].frames[fi].exportedAssetIds = kept
                        changed = true
                    }
                }
                let pairs = rolls[ri].frames[fi].exportedPairAssetIds
                if !pairs.isEmpty {
                    let kept = pairs.filter { live.contains($0) }
                    if kept.count != pairs.count {
                        rolls[ri].frames[fi].exportedPairAssetIds = kept
                        changed = true
                    }
                }
            }
        }
        if changed { persistSoon() }
    }

    func liveFrame(rollId: UUID, frameId: UUID) -> Frame? {
        guard let roll = rolls.first(where: { $0.id == rollId }) else { return nil }
        return roll.frames.first(where: { $0.id == frameId })
    }

    func markBlackHint() {
        hasSeenBlackHint = true
        persistSoon()
    }

    func markDarkboxHint() {
        guard !hasSeenDarkboxHint else { return }
        hasSeenDarkboxHint = true
        persistSoon()
    }

    func markAlbumHint() {
        guard !hasSeenAlbumHint else { return }
        hasSeenAlbumHint = true
        persistSoon()
    }

    func markEVHint() {
        guard !hasSeenEVHint else { return }
        hasSeenEVHint = true
        persistSoon()
    }

    func markFlashHint() {
        guard !hasSeenFlashHint else { return }
        hasSeenFlashHint = true
        persistSoon()
    }

    func markManualHint() {
        guard !hasSeenManualHint else { return }
        hasSeenManualHint = true
        persistSoon()
    }

    func markRewindHint() {
        guard !hasSeenRewindHint else { return }
        hasSeenRewindHint = true
        persistSoon()
    }

    func markExportHint() {
        guard !hasSeenExportHint else { return }
        hasSeenExportHint = true
        persistSoon()
    }

    func markKeepHint() {
        guard !hasSeenKeepHint else { return }
        hasSeenKeepHint = true
        persistSoon()
    }

    func setAutoExportPrints(_ on: Bool) {
        autoExportPrints = on
        persistSoon()
    }

    func setExportFilmBorder(_ on: Bool) {
        exportFilmBorder = on
        persistSoon()
    }

    func hasUnexportedPrints(_ roll: Roll) -> Bool {
        !unexportedDumpGroups(in: roll).isEmpty
    }

    var unexportedRollCount: Int {
        albumRolls.filter { hasUnexportedPrints($0) }.count
    }

    var unexportedFrameCount: Int {
        albumRolls.reduce(0) { $0 + unexportedDumpGroups(in: $1).count }
    }

    func formattedStorage() async -> String {
        let root = supportDir()
        let bytes = await Task.detached(priority: .utility) {
            Self.storageBytes(at: root)
        }.value
        guard bytes > 0 else { return "—" }
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useKB, .useMB, .useGB]
        fmt.countStyle = .file
        return fmt.string(fromByteCount: bytes)
    }

    func exportPrints(rollId: UUID) async -> PhotoExport.Outcome {
        await beginExport()
        defer { exportBusy = false }
        guard let roll = rolls.first(where: { $0.id == rollId }) else { return .noPrints }
        return await flushDumpGroups(rollId: roll.id, groups: unexportedDumpGroups(in: roll))
    }

    func exportAllUnexportedPrints() async -> PhotoExport.Outcome {
        await beginExport()
        defer { exportBusy = false }
        var saved = 0
        var lastFail: PhotoExport.Outcome?
        for roll in albumRolls {
            let groups = unexportedDumpGroups(in: roll)
            guard !groups.isEmpty else { continue }
            let outcome = await flushDumpGroups(rollId: roll.id, groups: groups)
            switch outcome {
            case .saved(let count, _):
                saved += count
            case .noPrints:
                continue
            case .noPermission, .failed:
                if saved == 0 { return outcome }
                lastFail = outcome
                return lastFail ?? .saved(saved, [])
            }
        }
        if saved > 0 { return .saved(saved, []) }
        return lastFail ?? .noPrints
    }

    func exportJPEGPayload(_ data: Data, rollId: UUID, frameIds: [UUID], asPair: Bool = false) async -> PhotoExport.Outcome {
        await beginExport()
        defer { exportBusy = false }
        let live = frameIds.compactMap { liveFrame(rollId: rollId, frameId: $0) }
        let fresh: [UUID]
        if asPair {
            guard !isPairDumped(live) else { return .noPrints }
            fresh = live.map(\.id)
        } else {
            fresh = live.filter { !$0.exported }.map(\.id)
        }
        guard !fresh.isEmpty else { return .noPrints }
        let outcome = await PhotoExport.saveJPEGs([data])
        if case .saved(_, let assetIds) = outcome {
            markExported(rollId: rollId, frameIds: fresh, assetId: assetIds.first, asPair: asPair)
        }
        return outcome
    }

    func applyFeel() {
        Soundboard.shared.enabled = soundOn
        Haptics.shared.enabled = hapticOn
        persistSoon()
    }

    func setStrictMode(_ on: Bool) {
        strictMode = on
        persistSoon()
    }

    func setLanguage(_ next: AppLanguage) {
        language = next
    }

    func setProRAW(_ on: Bool) {
        let next = on && camera.proRAWSupported
        proRAW = next
        camera.setProRAW(next)
        persistSoon()
    }

    func setAutoMacro(_ on: Bool) {
        autoMacro = on
        camera.setAutoMacro(on)
        persistSoon()
    }

    func dismissTutorialMask() {
        guard !tutorialMaskDismissed else { return }
        tutorialMaskDismissed = true
        persistSoon()
    }

    func completeOnboarding() {
        guard isOnboarding else { return }
        hasCompletedOnboarding = true
        persistNow()
    }

    func resetOnboardingForTest() {
        hasCompletedOnboarding = false
        tutorialMaskDismissed = false
        hasSeenHint = false
        hasSeenBlackHint = false
        hasSeenDarkboxHint = false
        hasSeenEVHint = false
        hasSeenFlashHint = false
        hasSeenManualHint = false
        hasSeenRewindHint = false
        hasSeenKeepHint = false
        if let roll = currentRoll {
            if roll.isTutorial || roll.shotCount == 0 {
                removeRollFiles(roll.id)
                rolls.removeAll { $0.id == roll.id }
                currentRollId = nil
            } else {
                forceUnload(ignoreStrict: true)
            }
        }
        let leftover = rolls.filter { $0.isTutorial && $0.state != .ready }
        for roll in leftover {
            DevelopNotify.cancel(rollId: roll.id)
            removeRollFiles(roll.id)
        }
        rolls.removeAll { $0.isTutorial && $0.state != .ready }
        developQueue.removeAll { id in leftover.contains { $0.id == id } }
        ritualRollId = nil
        pendingDevelopId = nil
        handoffToast = ""
        showSettings = false
        showAlbum = false
        showDarkbox = false
        showDarkroom = false
        persistNow()
        Task { await DevelopLive.sync(rolls: rolls) }
        pendingLoadRoll = true
    }

    private func removeRollFiles(_ id: UUID) {
        ImageStore.shared.purge(prefix: id.uuidString)
        try? FileManager.default.removeItem(at: rollDir(id))
    }

    func originalURL(rollId: UUID, fileName: String) -> URL {
        rollDir(rollId).appendingPathComponent(fileName)
    }

    func frameData(rollId: UUID, fileName: String) -> Data? {
        let url = originalURL(rollId: rollId, fileName: fileName)
        guard let sealed = try? Data(contentsOf: url) else { return nil }
        return FrameCrypto.open(sealed)
    }

    func originalImage(rollId: UUID, fileName: String) -> UIImage? {
        guard let data = frameData(rollId: rollId, fileName: fileName) else { return nil }
        return UIImage(data: data)
    }

    func positiveURL(rollId: UUID, fileName: String) -> URL {
        rollDir(rollId).appendingPathComponent(fileName)
    }

    func stillKey(roll: Roll, frame: Frame) -> String? {
        let name = frame.thumbFileName ?? frame.posFileName
        guard let name else { return nil }
        return "\(roll.id.uuidString)/\(name)"
    }

    func stillURL(roll: Roll, frame: Frame) -> URL? {
        let name = frame.thumbFileName ?? frame.posFileName
        guard let name else { return nil }
        return positiveURL(rollId: roll.id, fileName: name)
    }

    func cachedPreview(roll: Roll, frame: Frame) -> UIImage? {
        guard let key = stillKey(roll: roll, frame: frame) else { return nil }
        return ImageStore.shared.preview(key)
    }

    func cachedDisplay(roll: Roll, frame: Frame) -> UIImage? {
        guard let key = stillKey(roll: roll, frame: frame) else { return nil }
        return ImageStore.shared.display(key)
    }

    func cachedNegative(roll: Roll, frame: Frame) -> UIImage? {
        guard let key = stillKey(roll: roll, frame: frame) else { return nil }
        return ImageStore.shared.negative(key)
    }

    func loadPreview(roll: Roll, frame: Frame, priority: TaskPriority = .userInitiated) async -> UIImage? {
        guard let key = stillKey(roll: roll, frame: frame), let url = stillURL(roll: roll, frame: frame) else { return nil }
        return await ImageStore.shared.loadPreview(key: key, url: url, priority: priority)
    }

    func warmupAlbumCovers(priority: TaskPriority = .utility) async {
        if let flying = coverWarmup, let flyingPriority = coverWarmupPriority, flyingPriority >= priority {
            await flying.value
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let rolls = Array(self.albumRolls.prefix(8))
            for roll in rolls {
                await self.warmupCover(of: roll, priority: priority)
            }
        }
        coverWarmup = task
        coverWarmupPriority = priority
        await task.value
        if coverWarmup == task {
            coverWarmup = nil
            coverWarmupPriority = nil
        }
    }

    func warmupCover(of roll: Roll, priority: TaskPriority = .utility) async {
        let pair = filmPairs(roll.frames).first ?? []
        for frame in pair {
            while isCapturing {
                try? await Task.sleep(for: .milliseconds(400))
            }
            _ = await loadPreview(roll: roll, frame: frame, priority: priority)
        }
    }

    func loadDisplay(roll: Roll, frame: Frame) async -> UIImage? {
        guard let key = stillKey(roll: roll, frame: frame), let url = stillURL(roll: roll, frame: frame) else { return nil }
        return await ImageStore.shared.loadDisplay(key: key, url: url)
    }

    func loadNegative(roll: Roll, frame: Frame) async -> UIImage? {
        guard let key = stillKey(roll: roll, frame: frame), let url = stillURL(roll: roll, frame: frame) else { return nil }
        return await ImageStore.shared.loadNegative(key: key, url: url)
    }

    func exportImage(roll: Roll, frame: Frame, maxSide: CGFloat = 1600) -> UIImage? {
        guard let name = frame.posFileName else { return nil }
        let url = positiveURL(rollId: roll.id, fileName: name)
        return ImageStore.decodeExport(url, maxSide: maxSide)
    }

    func exportJPEGURL(roll: Roll, frame: Frame) -> URL? {
        guard let name = frame.posFileName else { return nil }
        let url = positiveURL(rollId: roll.id, fileName: name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func positiveExists(rollId: UUID, frame: Frame) -> Bool {
        let names = [frame.posFileName, frame.thumbFileName].compactMap { $0 }
        return names.contains { name in
            FileManager.default.fileExists(atPath: positiveURL(rollId: rollId, fileName: name).path)
        }
    }

    private func enqueueDevelop(_ id: UUID) {
        if !developQueue.contains(id) {
            developQueue.append(id)
        }
        Task { await pumpDevelop() }
    }

    private func pumpDevelop() async {
        guard !pipelineRunning else { return }
        guard let next = developQueue.first else { return }
        developQueue.removeFirst()
        pipelineRunning = true
        await runDevelop(next)
        pipelineRunning = false
        if !developQueue.isEmpty {
            await pumpDevelop()
        }
    }

    private func runDevelop(_ id: UUID) async {
        await waitForWrites()
        guard let idx = rolls.firstIndex(where: { $0.id == id }) else { return }
        let roll = rolls[idx]
        let recipe = FilmCatalog.recipe(id: roll.filmId)
        let total = max(1, roll.frames.count)
        let track = ritualRollId == id
        var done = 0
        for frame in roll.frames {
            if frame.developed, frame.posFileName != nil, positiveExists(rollId: roll.id, frame: frame) {
                done += 1
            }
        }
        if track { developProgress = Double(done) / Double(total) }
        for (i, frame) in roll.frames.enumerated() {
            if frame.developed, frame.posFileName != nil, positiveExists(rollId: roll.id, frame: frame) { continue }
            let posName = String(format: "%03d_pos.jpg", frame.index)
            let thumbName = String(format: "%03d_thm.jpg", frame.index)
            if FileManager.default.fileExists(atPath: originalURL(rollId: roll.id, fileName: posName).path) {
                if let live = rolls.firstIndex(where: { $0.id == id }) {
                    rolls[live].frames[i].posFileName = posName
                    if FileManager.default.fileExists(atPath: originalURL(rollId: roll.id, fileName: thumbName).path) {
                        rolls[live].frames[i].thumbFileName = thumbName
                    }
                    rolls[live].frames[i].developed = true
                }
                done += 1
                if track { developProgress = Double(done) / Double(total) }
                continue
            }
            guard let data = frameData(rollId: roll.id, fileName: frame.fileName) else { continue }
            let out = await Task.detached(priority: .userInitiated) {
                SpektraEngine.shared.develop(data: data, recipe: recipe, roll: roll, frame: frame)
            }.value
            guard let out else { continue }
            do {
                try out.positive.write(to: originalURL(rollId: roll.id, fileName: posName), options: .atomic)
                try out.thumb.write(to: originalURL(rollId: roll.id, fileName: thumbName), options: .atomic)
            } catch {
                continue
            }
            if let live = rolls.firstIndex(where: { $0.id == id }) {
                rolls[live].frames[i].posFileName = posName
                rolls[live].frames[i].thumbFileName = thumbName
                rolls[live].frames[i].developed = true
            }
            done += 1
            if track { developProgress = Double(done) / Double(total) }
        }
        if track { developProgress = 1 }
        persistNow()
        if let live = rolls.first(where: { $0.id == id }) {
            await warmupCover(of: live)
        }
        Task { await warmupAlbumCovers() }
    }

    private func upsert(_ roll: Roll) {
        if let i = rolls.firstIndex(where: { $0.id == roll.id }) {
            rolls[i] = roll
        } else {
            rolls.append(roll)
        }
    }

    private func rollDir(_ id: UUID) -> URL {
        supportDir().appendingPathComponent("rolls").appendingPathComponent(id.uuidString)
    }

    private func supportDir() -> URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HalfCam", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private struct DumpJob {
        var frameIds: [UUID]
        var data: Data
        var asPair: Bool
    }

    private func flushDumpGroups(rollId: UUID, groups: [[Frame]]) async -> PhotoExport.Outcome {
        guard let roll = rolls.first(where: { $0.id == rollId }) else { return .noPrints }
        var jobs: [DumpJob] = []
        for pair in groups {
            let ready = pair.filter { $0.developed && $0.posFileName != nil }
            guard !ready.isEmpty else { continue }
            let urls = ready.compactMap { exportJPEGURL(roll: roll, frame: $0) }
            guard !urls.isEmpty else { continue }
            let asPair = ready.count >= 2
            let bordered = exportFilmBorder
            let rebates = bordered ? ready.map { filmRebate($0.index) } : []
            let data = await Task.detached(priority: .userInitiated) {
                PhotoExport.composeJPEG(urls: urls, rebates: rebates, filmBorder: bordered)
            }.value
            guard let data else { continue }
            jobs.append(DumpJob(frameIds: ready.map(\.id), data: data, asPair: asPair))
        }
        return await flushDumpJobs(rollId: rollId, jobs: jobs)
    }

    private func flushDumpJobs(rollId: UUID, jobs: [DumpJob]) async -> PhotoExport.Outcome {
        guard !jobs.isEmpty else { return .noPrints }
        var saved = 0
        var lastFail: PhotoExport.Outcome?
        chunkLoop: for chunk in stride(from: 0, to: jobs.count, by: PhotoExport.batchSize) {
            let slice = Array(jobs[chunk..<min(chunk + PhotoExport.batchSize, jobs.count)])
            let outcome = await PhotoExport.saveJPEGs(slice.map(\.data))
            switch outcome {
            case .saved(let count, let assetIds):
                saved += count
                for (i, job) in slice.enumerated() {
                    let assetId = i < assetIds.count ? assetIds[i] : nil
                    markExported(rollId: rollId, frameIds: job.frameIds, assetId: assetId, asPair: job.asPair)
                }
            case .noPrints:
                continue
            case .noPermission, .failed:
                if saved == 0 { return outcome }
                lastFail = outcome
                break chunkLoop
            }
        }
        if saved > 0 { return .saved(saved, []) }
        return lastFail ?? .noPrints
    }

    private func beginExport() async {
        while exportBusy {
            try? await Task.sleep(for: .milliseconds(40))
        }
        exportBusy = true
    }

    private func flashExportNotice(_ text: String) {
        exportNotice = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            if exportNotice == text { exportNotice = "" }
        }
    }

    private nonisolated static func storageBytes(at root: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    private func persistSoon() {
        persistTask?.cancel()
        persistTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            persistNow()
        }
    }

    private func persistNow() {
        persistTask?.cancel()
        persistTask = nil
        persist()
    }

    private func persist() {
        let store = PersistStore(
            rolls: rolls,
            currentRollId: currentRollId,
            flashOn: flashOn,
            soundOn: soundOn,
            hapticOn: hapticOn,
            proRAW: proRAW,
            hasSeenHint: hasSeenHint,
            hasSeenBlackHint: hasSeenBlackHint,
            hasSeenDarkboxHint: hasSeenDarkboxHint,
            hasSeenAlbumHint: hasSeenAlbumHint,
            hasSeenEVHint: hasSeenEVHint,
            hasSeenFlashHint: hasSeenFlashHint,
            hasSeenManualHint: hasSeenManualHint,
            hasSeenRewindHint: hasSeenRewindHint,
            hasSeenExportHint: hasSeenExportHint,
            hasSeenKeepHint: hasSeenKeepHint,
            autoExportPrints: autoExportPrints,
            exportFilmBorder: exportFilmBorder,
            manualMode: manualMode,
            strictMode: strictMode,
            hasCompletedOnboarding: hasCompletedOnboarding,
            tutorialMaskDismissed: tutorialMaskDismissed,
            autoMacro: autoMacro,
            loadsThisMonth: loadsThisMonth,
            loadMonthStamp: loadMonthStamp,
            skipGranted: skipGranted,
            skipPurchased: skipPurchased,
            skipGrantQuota: skipGrantQuota,
            skipCloudUpdatedAt: skipCloudUpdatedAt
        )
        let url = supportDir().appendingPathComponent("store.json")
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        if let data = try? enc.encode(store) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func load() {
        let url = supportDir().appendingPathComponent("store.json")
        guard let data = try? Data(contentsOf: url) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let store = try? dec.decode(PersistStore.self, from: data) else { return }
        rolls = store.rolls
        currentRollId = store.currentRollId
        flashOn = store.flashOn
        soundOn = store.soundOn
        hapticOn = store.hapticOn
        proRAW = store.proRAW ?? false
        camera.setProRAW(proRAW)
        hasSeenHint = store.hasSeenHint
        hasSeenBlackHint = store.hasSeenBlackHint ?? false
        hasSeenDarkboxHint = store.hasSeenDarkboxHint ?? false
        hasSeenAlbumHint = store.hasSeenAlbumHint ?? false
        hasSeenEVHint = store.hasSeenEVHint ?? false
        hasSeenFlashHint = store.hasSeenFlashHint ?? false
        hasSeenManualHint = store.hasSeenManualHint ?? false
        hasSeenRewindHint = store.hasSeenRewindHint ?? false
        hasSeenExportHint = store.hasSeenExportHint ?? false
        hasSeenKeepHint = store.hasSeenKeepHint ?? false
        autoExportPrints = store.autoExportPrints ?? true
        exportFilmBorder = store.exportFilmBorder ?? true
        manualMode = store.manualMode ?? false
        strictMode = store.strictMode ?? true
        hasCompletedOnboarding = store.hasCompletedOnboarding ?? !rolls.isEmpty
        tutorialMaskDismissed = store.tutorialMaskDismissed ?? false
        autoMacro = true
        camera.setAutoMacro(true)
        loadsThisMonth = store.loadsThisMonth ?? 0
        loadMonthStamp = store.loadMonthStamp ?? ""
        skipGranted = store.skipGranted ?? 0
        skipPurchased = store.skipPurchased ?? store.skipTickets ?? 0
        skipGrantQuota = store.skipGrantQuota ?? 0
        skipCloudUpdatedAt = store.skipCloudUpdatedAt ?? 0
    }

    private static let cloudSkipLedgerKey = "halfcam.cloud.skipLedger"

    private func listenSkipCloud() {
        NSUbiquitousKeyValueStore.default.synchronize()
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.handleSkipCloudChange(note)
            }
        }
        NotificationCenter.default.addObserver(
            forName: .halfcamSkipCloudRestore,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pullSkipCloud()
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !skipCloudReady else { return }
            skipCloudReady = true
            if skipPurchased > 0 {
                pushSkipCloud()
            }
        }
    }

    private func handleSkipCloudChange(_ note: Notification) {
        let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        if reason == NSUbiquitousKeyValueStoreInitialSyncChange
            || reason == NSUbiquitousKeyValueStoreServerChange {
            skipCloudReady = true
        }
        pullSkipCloud()
    }

    private func pullSkipCloud() {
        let cloud = NSUbiquitousKeyValueStore.default
        cloud.synchronize()
        guard let data = cloud.data(forKey: Self.cloudSkipLedgerKey),
              let ledger = try? JSONDecoder().decode(SkipCloudLedger.self, from: data)
        else {
            if skipCloudReady, skipPurchased > 0 {
                pushSkipCloud()
            }
            return
        }
        skipCloudReady = true
        let firstUpgrade = skipCloudUpdatedAt == 0 && (skipPurchased > 0 || skipGranted > 0)
        if firstUpgrade {
            skipPurchased = max(skipPurchased, ledger.skipPurchased)
            let current = AppConst.monthStamp()
            if ledger.loadMonthStamp == current {
                skipGranted = max(skipGranted, ledger.skipGranted)
                skipGrantQuota = max(skipGrantQuota, ledger.skipGrantQuota)
                if loadMonthStamp != current {
                    loadMonthStamp = ledger.loadMonthStamp
                }
            }
            persistNow()
            pushSkipCloud()
            return
        }
        guard ledger.updatedAt >= skipCloudUpdatedAt else { return }
        skipPurchased = ledger.skipPurchased
        let current = AppConst.monthStamp()
        if ledger.loadMonthStamp == current {
            skipGranted = ledger.skipGranted
            skipGrantQuota = ledger.skipGrantQuota
            if loadMonthStamp != current {
                loadMonthStamp = ledger.loadMonthStamp
            }
        }
        skipCloudUpdatedAt = ledger.updatedAt
        persistNow()
    }

    private func pushSkipCloud() {
        guard skipCloudReady else { return }
        skipCloudUpdatedAt = Date().timeIntervalSince1970
        let ledger = SkipCloudLedger(
            skipPurchased: skipPurchased,
            skipGranted: skipGranted,
            skipGrantQuota: skipGrantQuota,
            loadMonthStamp: loadMonthStamp,
            updatedAt: skipCloudUpdatedAt
        )
        if let data = try? JSONEncoder().encode(ledger) {
            NSUbiquitousKeyValueStore.default.set(data, forKey: Self.cloudSkipLedgerKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
        persistNow()
    }
}
