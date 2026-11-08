import AVFoundation
import Observation
import UIKit

struct LensStop: Hashable, Identifiable {
    var factor: CGFloat
    var zoomLabel: String
    var mmLabel: String
    var id: CGFloat { factor }
}

@Observable
final class CameraSession: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "halfcam.session")
    @ObservationIgnored private var device: AVCaptureDevice?
    @ObservationIgnored private var virtualDevice: AVCaptureDevice?
    @ObservationIgnored private var ultraDevice: AVCaptureDevice?
    @ObservationIgnored private var wideDevice: AVCaptureDevice?
    @ObservationIgnored private var teleDevice: AVCaptureDevice?
    @ObservationIgnored private var usingPhysical = false
    @ObservationIgnored private var pendingShutter: CMTime?
    @ObservationIgnored private var pendingISO: Float?
    @ObservationIgnored private var pendingLens: Float?
    @ObservationIgnored private var pendingEVFactor: Float = 1
    @ObservationIgnored private var zoomFactor: CGFloat = 1
    @ObservationIgnored private var lastFocusPoint: CGPoint?
    @ObservationIgnored private var focusRetry = 0
    @ObservationIgnored private var continuation: CheckedContinuation<Data?, Never>?
    @ObservationIgnored private var committed: (() -> Void)?
    private let lock = NSLock()
    @ObservationIgnored private var proRAWEnabled = true
    var hasCamera = false
    var cameraDenied = false
    var flashOn = false
    var exposureLocked = false
    var focusLocked = false
    var lensStops: [LensStop] = []
    var apertureStops: [Float] = []
    var currentAperture: Float?
    var currentZoom: CGFloat = 1
    var focusIndicator: CGPoint?
    var syncedFocusLens: Float?
    var currentMinFocusMeters: Double = 0.2
    @ObservationIgnored private var cameraAvailable = false
    @ObservationIgnored private var wideFactor: CGFloat = 1
    @ObservationIgnored private var teleNative: CGFloat = 3
    var savedEV: Float = 0
    @ObservationIgnored private var lastISO: Float = 400
    @ObservationIgnored private var lastDuration = CMTime(value: 1, timescale: 125)
    @ObservationIgnored private var lastAppliedEVFactor: Float = 1
    struct Meter {
        var iso: Float
        var shutter: Double
        var lens: Float
    }
    @ObservationIgnored var lastMeter = Meter(iso: 400, shutter: 1.0 / 125.0, lens: 1)

    func start() {
        queue.async { [weak self] in
            self?.requestAndRun()
        }
    }

    private func requestAndRun() {
        let run = { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if self.cameraAvailable, !self.session.isRunning {
                self.session.startRunning()
                self.prepareCapture()
            }
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.hasCameraDenied(false) }
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                DispatchQueue.main.async { self?.hasCameraDenied(!ok) }
                guard ok else { return }
                self?.queue.async { run() }
            }
        default:
            DispatchQueue.main.async { self.hasCameraDenied(true) }
        }
    }

    func refreshPermission() {
        queue.async { [weak self] in
            self?.requestAndRun()
        }
    }

    func ensureAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            let ok = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { hasCameraDenied(!ok) }
            if ok {
                queue.async { self.requestAndRun() }
            }
            return ok
        default:
            await MainActor.run { hasCameraDenied(true) }
            return false
        }
    }

    private func hasCameraDenied(_ denied: Bool) {
        cameraDenied = denied
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func setProRAW(_ on: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            self.proRAWEnabled = on
            if self.photoOutput.isAppleProRAWSupported {
                self.photoOutput.isAppleProRAWEnabled = on
            }
            self.photoOutput.maxPhotoQualityPrioritization = on ? .balanced : .speed
            if self.cameraAvailable {
                self.prepareCapture()
            }
        }
    }

    func capture(onCommitted: (() -> Void)? = nil) async -> Data? {
        await withCheckedContinuation { cont in
            let fireCommitted = {
                if let onCommitted {
                    DispatchQueue.main.async { onCommitted() }
                }
            }
            guard cameraAvailable else {
                fireCommitted()
                cont.resume(returning: Self.mockJPEG())
                return
            }
            if !session.isRunning {
                start()
                fireCommitted()
                cont.resume(returning: nil)
                return
            }
            lock.lock()
            if continuation != nil {
                lock.unlock()
                fireCommitted()
                cont.resume(returning: nil)
                return
            }
            continuation = cont
            committed = onCommitted
            lock.unlock()
            if let device {
                lastMeter = Meter(
                    iso: device.iso,
                    shutter: CMTimeGetSeconds(device.exposureDuration),
                    lens: device.lensPosition
                )
            }
            photoOutput.capturePhoto(with: makeSettings(), delegate: self)
        }
    }

    func setEV(_ ev: Float) {
        savedEV = ev
        pendingEVFactor = powf(2, ev)
        queue.async { [weak self] in
            guard let self, let device = self.device else { return }
            if self.exposureLocked {
                self.applyLockedSettings(afterSwitch: false)
                return
            }
            do {
                try device.lockForConfiguration()
                let clamped = min(max(ev, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.setExposureTargetBias(clamped)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func applyAuto() {
        exposureLocked = false
        focusLocked = false
        pendingShutter = nil
        pendingISO = nil
        pendingLens = nil
        pendingEVFactor = powf(2, savedEV)
        lastFocusPoint = nil
        queue.async { [weak self] in
            guard let self else { return }
            self.switchTo(self.virtualDevice, physical: false)
            self.showFocus(nil)
            guard let device = self.device else { return }
            do {
                try device.lockForConfiguration()
                self.applyZoomOnCurrentDevice(device)
                self.applyContinuousFocus(device)
                self.applyContinuousExposure(device)
                self.restorePreviewFrameRate(device)
                let ev = min(max(self.savedEV, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.setExposureTargetBias(ev)
                self.sampleMeter(device)
                self.lastAppliedEVFactor = powf(2, self.savedEV)
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func applyMixed(shutter: CMTime?, iso: Float?, evFactor: Float = 1) {
        exposureLocked = shutter != nil || iso != nil
        pendingShutter = shutter
        pendingISO = iso
        pendingEVFactor = evFactor
        queue.async { [weak self] in
            guard let self else { return }
            let needsPhysical = self.exposureLocked || self.focusLocked
            let target = needsPhysical ? self.physicalForZoom() : self.virtualDevice
            let switched = self.switchTo(target, physical: needsPhysical)
            self.applyLockedSettings(afterSwitch: switched)
        }
    }

    func unlockFocus() {
        focusLocked = false
        pendingLens = nil
        queue.async { [weak self] in
            guard let self, let device = self.device else { return }
            do {
                try device.lockForConfiguration()
                self.applyContinuousFocus(device)
                device.unlockForConfiguration()
            } catch {}
            let needsPhysical = self.exposureLocked
            if !needsPhysical {
                self.switchTo(self.virtualDevice, physical: false)
                if let device = self.device {
                    try? device.lockForConfiguration()
                    self.applyZoomOnCurrentDevice(device)
                    self.applyContinuousFocus(device)
                    device.unlockForConfiguration()
                }
            }
        }
    }

    func setManualFocus(_ position: Float) {
        let pos = min(max(position, 0), 1)
        focusLocked = true
        pendingLens = pos
        queue.async { [weak self] in
            guard let self else { return }
            if let device = self.device, self.usingPhysical {
                self.lockLens(device, pos)
                return
            }
            let switched = self.switchTo(self.physicalForZoom(), physical: true)
            self.focusRetry = 0
            if switched {
                self.queue.asyncAfter(deadline: .now() + 0.16) { [weak self] in
                    self?.lockPendingFocus()
                }
            } else {
                self.lockPendingFocus()
            }
        }
    }

    private func sampleMeter(_ device: AVCaptureDevice) {
        lastISO = device.iso
        lastDuration = device.exposureDuration
    }

    func focus(at point: CGPoint) {
        queue.async { [weak self] in
            guard let self, let device = self.device, !self.focusLocked else { return }
            self.lastFocusPoint = point
            self.showFocus(point)
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                }
                self.applyContinuousFocus(device)
                if device.isExposurePointOfInterestSupported, !self.exposureLocked {
                    device.exposurePointOfInterest = point
                    self.applyContinuousExposure(device)
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func setZoom(_ factor: CGFloat) {
        queue.async { [weak self] in
            guard let self else { return }
            self.zoomFactor = factor
            DispatchQueue.main.async { self.currentZoom = factor }
            let needsPhysical = self.exposureLocked || self.focusLocked
            if needsPhysical {
                let target = self.physicalForZoom(factor)
                if let device = self.device, device === target, self.usingPhysical {
                    self.applyLockedSettings(afterSwitch: false)
                } else {
                    let switched = self.switchTo(target, physical: true)
                    self.applyLockedSettings(afterSwitch: switched)
                }
            } else if let device = self.device {
                let z = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = z
                    self.applyDistortion(device, zoom: z)
                    device.unlockForConfiguration()
                } catch {}
            }
        }
    }

    private func configureIfNeeded() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let cam = pickCamera(),
           let input = try? AVCaptureDeviceInput(device: cam),
           session.canAddInput(input) {
            session.addInput(input)
            device = cam
            virtualDevice = cam
            discoverPhysical()
            cameraAvailable = true
            let stops = Self.makeStops(cam)
            let wide = stops.first(where: { $0.zoomLabel == "1×" || $0.zoomLabel == "1" })?.factor ?? max(1, cam.minAvailableVideoZoomFactor)
            wideFactor = wide
            zoomFactor = wide
            let meters = Self.minFocusMeters(cam)
            DispatchQueue.main.async { self.currentMinFocusMeters = meters }
            let switchOvers = cam.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
            if let last = switchOvers.filter({ $0 > wide + 0.05 }).max() {
                teleNative = max(2, last / max(wide, 0.01))
            } else if teleDevice != nil {
                teleNative = 3
            }
            DispatchQueue.main.async {
                self.hasCamera = true
                self.lensStops = stops
                self.currentZoom = wide
            }
            try? cam.lockForConfiguration()
            applyContinuousFocus(cam)
            applyContinuousExposure(cam)
            let z = min(max(wide, cam.minAvailableVideoZoomFactor), cam.maxAvailableVideoZoomFactor)
            cam.videoZoomFactor = z
            applyDistortion(cam, zoom: z)
            cam.unlockForConfiguration()
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        if let conn = photoOutput.connection(with: .video) {
            if conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90
            }
            conn.isVideoMirrored = false
        }
        photoOutput.maxPhotoQualityPrioritization = proRAWEnabled ? .balanced : .speed
        if photoOutput.isFastCapturePrioritizationSupported {
            photoOutput.isFastCapturePrioritizationEnabled = true
        }
        if photoOutput.isResponsiveCaptureSupported {
            photoOutput.isResponsiveCaptureEnabled = true
        }
        if photoOutput.isZeroShutterLagSupported {
            photoOutput.isZeroShutterLagEnabled = true
        }
        if let device {
            probeAperture(device)
        }
        if photoOutput.isAppleProRAWSupported {
            photoOutput.isAppleProRAWEnabled = proRAWEnabled
        }
        session.commitConfiguration()
    }

    private func prepareCapture() {
        photoOutput.setPreparedPhotoSettingsArray([makeSettings()], completionHandler: nil)
    }

    private func pickCamera() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let found = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .back
        ).devices
        for type in types {
            if let cam = found.first(where: { $0.deviceType == type }) { return cam }
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private func discoverPhysical() {
        ultraDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        wideDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        teleDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
    }

    private func physicalForZoom(_ factor: CGFloat? = nil) -> AVCaptureDevice? {
        let z = factor ?? zoomFactor
        let display = z / max(wideFactor, 0.01)
        if display < 0.75 { return ultraDevice ?? wideDevice ?? virtualDevice }
        if display >= 2.8, let teleDevice { return teleDevice }
        if display >= teleNative * 0.85, let teleDevice { return teleDevice }
        return wideDevice ?? virtualDevice
    }

    @discardableResult
    private func switchTo(_ target: AVCaptureDevice?, physical: Bool) -> Bool {
        guard let target else { return false }
        if device === target, usingPhysical == physical { return false }
        let old = device
        let oldInputs = session.inputs
        session.beginConfiguration()
        for input in oldInputs {
            session.removeInput(input)
        }
        guard let input = try? AVCaptureDeviceInput(device: target), session.canAddInput(input) else {
            for input in oldInputs where session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
            return false
        }
        if physical, let old, let lens = pendingLens, old !== target {
            let remapped = Self.remapLens(lens, from: old, to: target)
            pendingLens = remapped
            DispatchQueue.main.async { self.syncedFocusLens = remapped }
        }
        session.addInput(input)
        device = target
        usingPhysical = physical
        let meters = Self.minFocusMeters(target)
        DispatchQueue.main.async { self.currentMinFocusMeters = meters }
        if let conn = photoOutput.connection(with: .video), conn.isVideoRotationAngleSupported(90) {
            conn.videoRotationAngle = 90
            conn.isVideoMirrored = false
        }
        session.commitConfiguration()
        if !focusLocked {
            prepareCapture()
        }
        return true
    }

    private func applyLockedSettings(afterSwitch: Bool = false) {
        let apply = { [weak self] in
            guard let self, let device = self.device else { return }
            do {
                try device.lockForConfiguration()
                self.applyZoomOnCurrentDevice(device)
                if self.pendingShutter == nil, self.pendingISO == nil {
                    self.applyContinuousExposure(device)
                    self.restorePreviewFrameRate(device)
                    let ev = min(max(self.savedEV, device.minExposureTargetBias), device.maxExposureTargetBias)
                    device.setExposureTargetBias(ev)
                    self.lastAppliedEVFactor = powf(2, self.savedEV)
                } else {
                    let format = device.activeFormat
                    let currentDur = device.exposureDuration
                    let currentISO = device.iso
                    var dur = self.pendingShutter ?? currentDur
                    var isoV = self.pendingISO ?? currentISO
                    let evRatio = self.lastAppliedEVFactor > 0.001
                        ? self.pendingEVFactor / self.lastAppliedEVFactor
                        : 1
                    if self.pendingShutter != nil, self.pendingISO == nil {
                        let oldSec = max(CMTimeGetSeconds(currentDur), 0.0001)
                        let newSec = max(CMTimeGetSeconds(dur), 0.0001)
                        isoV = currentISO * Float(oldSec / newSec) * evRatio
                    } else if self.pendingShutter == nil, self.pendingISO != nil {
                        dur = CMTimeMultiplyByFloat64(currentDur, multiplier: Float64(evRatio))
                        isoV = self.pendingISO ?? currentISO
                    } else {
                        isoV = (self.pendingISO ?? currentISO) * self.pendingEVFactor
                    }
                    dur = min(max(dur, format.minExposureDuration), format.maxExposureDuration)
                    isoV = min(max(isoV, format.minISO), format.maxISO)
                    self.syncPreviewFrameRate(device, duration: dur)
                    if device.isExposureModeSupported(.custom) {
                        device.setExposureModeCustom(duration: dur, iso: isoV, completionHandler: nil)
                    }
                    self.lastAppliedEVFactor = self.pendingEVFactor
                }
                self.sampleMeter(device)
                device.unlockForConfiguration()
            } catch {}
            if afterSwitch, self.focusLocked {
                self.refineFocusAfterSwitch()
            } else {
                self.lockPendingFocus()
            }
        }
        if afterSwitch {
            focusRetry = 0
            queue.asyncAfter(deadline: .now() + 0.18, execute: apply)
        } else {
            apply()
        }
    }

    private func refineFocusAfterSwitch() {
        guard let device, focusLocked else {
            lockPendingFocus()
            return
        }
        let point = lastFocusPoint ?? CGPoint(x: 0.5, y: 0.5)
        showFocus(point)
        if device.isFocusPointOfInterestSupported {
            do {
                try device.lockForConfiguration()
                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = false
                }
                device.focusPointOfInterest = point
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
                device.unlockForConfiguration()
            } catch {}
            queue.asyncAfter(deadline: .now() + 0.28) { [weak self] in
                guard let self, let device = self.device, self.focusLocked else { return }
                let pos = device.lensPosition
                self.pendingLens = pos
                DispatchQueue.main.async { self.syncedFocusLens = pos }
                self.lockPendingFocus()
            }
        } else {
            lockPendingFocus()
        }
    }

    private func lockPendingFocus() {
        guard let device, let pos = pendingLens else { return }
        disableSmoothAF(device)
        if device.isFocusModeSupported(.locked) {
            lockLens(device, pos)
            return
        }
        if focusRetry < 8 {
            focusRetry += 1
            queue.asyncAfter(deadline: .now() + 0.07) { [weak self] in
                self?.lockPendingFocus()
            }
        }
    }

    private func lockLens(_ device: AVCaptureDevice, _ pos: Float) {
        let clamped = min(max(pos, 0), 1)
        do {
            try device.lockForConfiguration()
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = false
            }
            device.setFocusModeLocked(lensPosition: clamped) { [weak self] _ in
                self?.queue.async {
                    guard let self, let device = self.device else { return }
                    if abs(device.lensPosition - clamped) > 0.08, self.focusRetry < 6 {
                        self.focusRetry += 1
                        self.lockLens(device, clamped)
                    }
                }
            }
            device.unlockForConfiguration()
            showFocus(lastFocusPoint ?? CGPoint(x: 0.5, y: 0.5))
        } catch {}
    }

    private func disableSmoothAF(_ device: AVCaptureDevice) {
        guard device.isSmoothAutoFocusSupported, device.isSmoothAutoFocusEnabled else { return }
        do {
            try device.lockForConfiguration()
            device.isSmoothAutoFocusEnabled = false
            device.unlockForConfiguration()
        } catch {}
    }

    private func applyFocusLock(_ device: AVCaptureDevice) {
        if pendingLens != nil {
            lockPendingFocus()
        } else {
            applyContinuousFocus(device)
            if let point = lastFocusPoint, device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                showFocus(point)
            }
        }
    }

    private func showFocus(_ point: CGPoint?) {
        DispatchQueue.main.async {
            self.focusIndicator = point
        }
        guard point != nil else { return }
        queue.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            DispatchQueue.main.async {
                if self?.focusIndicator == point { self?.focusIndicator = nil }
            }
        }
    }

    private func applyZoomOnCurrentDevice(_ device: AVCaptureDevice) {
        let display = zoomFactor / max(wideFactor, 0.01)
        let z: CGFloat
        if usingPhysical {
            switch device.deviceType {
            case .builtInUltraWideCamera:
                z = device.minAvailableVideoZoomFactor
            case .builtInTelephotoCamera:
                let extra = display / max(teleNative, 0.01)
                z = extra <= 1.12
                    ? device.minAvailableVideoZoomFactor
                    : min(max(extra, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            default:
                z = min(max(display, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            }
        } else {
            z = min(max(zoomFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        }
        device.videoZoomFactor = z
        applyDistortion(device, zoom: usingPhysical ? zoomFactor : z)
    }

    private static func makeStops(_ device: AVCaptureDevice) -> [LensStop] {
        let minZ = device.minAvailableVideoZoomFactor
        let maxZ = device.maxAvailableVideoZoomFactor
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { CGFloat(truncating: $0) }
            .filter { $0 <= maxZ + 0.01 }
        let hasUltra = minZ < 0.99 || device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
        let wide: CGFloat
        if hasUltra, minZ < 0.99 {
            wide = 1
        } else if hasUltra, let first = switchOvers.first, first > minZ + 0.05 {
            wide = first
        } else {
            wide = minZ
        }
        var factors: [CGFloat] = [minZ]
        if abs(wide - minZ) > 0.05 { factors.append(wide) }
        for stop in switchOvers where stop > wide + 0.05 {
            factors.append(stop)
        }
        for display in [1.5, 2.0] {
            let factor = wide * display
            guard factor <= maxZ + 0.01 else { continue }
            if factors.contains(where: { abs($0 - factor) < 0.08 }) { continue }
            factors.append(factor)
        }
        factors.sort()
        var seen = Set<CGFloat>()
        return factors.compactMap { factor in
            let rounded = (factor * 100).rounded() / 100
            guard seen.insert(rounded).inserted else { return nil }
            let display = factor / max(wide, 0.01)
            return LensStop(factor: factor, zoomLabel: zoomLabel(display), mmLabel: mmLabel(display))
        }
    }

    private static func zoomLabel(_ display: CGFloat) -> String {
        if abs(display - display.rounded()) < 0.05 {
            return "\(Int(display.rounded()))×"
        }
        return String(format: "%.1f×", display)
    }

    private static func mmLabel(_ display: CGFloat) -> String {
        "\(Int((24 * display).rounded()))mm"
    }

    static func focusDistance(slider: Float, minFocus: Double = 0.2) -> Double {
        let t = Double(min(max(slider, 0), 1))
        if t >= 0.97 { return .infinity }
        return minFocus / max(1 - t, 0.02)
    }

    static func slider(distance meters: Double, minFocus: Double = 0.2) -> Float {
        guard meters.isFinite, meters > 0 else { return 1 }
        if meters <= minFocus { return 0 }
        return Float(min(max(1 - minFocus / meters, 0), 1))
    }

    private static func remapLens(_ p: Float, from _: AVCaptureDevice, to new: AVCaptureDevice) -> Float {
        let t = Double(min(max(p, 0), 1))
        if t >= 0.97 { return 1 }
        let d = 0.4 * pow(25, t)
        let minNew = minFocusMeters(new)
        if d <= minNew { return 0 }
        return Float(min(max(1 - minNew / d, 0), 1))
    }

    private static func minFocusMeters(_ device: AVCaptureDevice?) -> Double {
        guard let device else { return 0.2 }
        let meters = Double(device.minimumFocusDistance) / 1000
        if meters >= 0.05, meters <= 5 { return meters }
        switch device.deviceType {
        case .builtInUltraWideCamera: return 0.12
        case .builtInTelephotoCamera: return 1.2
        default: return 0.2
        }
    }

    private func applyContinuousFocus(_ device: AVCaptureDevice) {
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = !focusLocked
        }
        if focusLocked { return }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
    }

    private func applyContinuousExposure(_ device: AVCaptureDevice) {
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
    }

    private func syncPreviewFrameRate(_ device: AVCaptureDevice, duration: CMTime) {
        let seconds = CMTimeGetSeconds(duration)
        guard seconds > 1.0 / 24.0 else {
            restorePreviewFrameRate(device)
            return
        }
        let ranges = device.activeFormat.videoSupportedFrameRateRanges
        guard let range = ranges.max(by: { $0.maxFrameDuration < $1.maxFrameDuration }) ?? ranges.first else { return }
        var frame = duration
        if CMTimeCompare(frame, range.minFrameDuration) < 0 { frame = range.minFrameDuration }
        if CMTimeCompare(frame, range.maxFrameDuration) > 0 { frame = range.maxFrameDuration }
        device.activeVideoMinFrameDuration = frame
        device.activeVideoMaxFrameDuration = frame
    }

    private func restorePreviewFrameRate(_ device: AVCaptureDevice) {
        device.activeVideoMinFrameDuration = .invalid
        device.activeVideoMaxFrameDuration = .invalid
    }

    private func applyDistortion(_ device: AVCaptureDevice, zoom: CGFloat) {
        guard device.isGeometricDistortionCorrectionSupported else { return }
        device.isGeometricDistortionCorrectionEnabled = zoom < wideFactor * 0.98
    }

    private func makeSettings() -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        let rawType = photoOutput.availableRawPhotoPixelFormatTypes.first(where: {
            AVCapturePhotoOutput.isAppleProRAWPixelFormat($0)
        })
        if photoOutput.isAppleProRAWEnabled, let rawType {
            settings = AVCapturePhotoSettings(rawPixelFormatType: rawType)
        } else if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        settings.photoQualityPrioritization = photoOutput.isAppleProRAWEnabled ? .balanced : .speed
        if photoOutput.supportedFlashModes.contains(flashOn ? .on : .off) {
            settings.flashMode = flashOn ? .on : .off
        }
        return settings
    }

    private func finishCapture(_ data: Data?) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: data)
    }

    static func mockJPEG() -> Data? {
        let size = CGSize(width: 1512, height: 2016)
        let renderer = UIGraphicsImageRenderer(size: size)
        let hue = CGFloat((Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 12)) / 12)
        let image = renderer.image { ctx in
            let colors = [
                UIColor(hue: hue, saturation: 0.28, brightness: 0.78, alpha: 1).cgColor,
                UIColor(hue: hue + 0.12, saturation: 0.35, brightness: 0.42, alpha: 1).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            UIColor(white: 1, alpha: 0.18).setFill()
            UIBezierPath(ovalIn: CGRect(x: size.width * 0.18, y: size.height * 0.22, width: size.width * 0.45, height: size.width * 0.45)).fill()
        }
        return image.jpegData(compressionQuality: 0.86)
    }

    func setAperture(_ value: Float) {
        queue.async { [weak self] in
            guard let self, let device = self.device else { return }
            Self.applyAperture(device, value)
            DispatchQueue.main.async { self.currentAperture = value }
        }
    }

    private func probeAperture(_ device: AVCaptureDevice) {
        let keys = ["supportedApertures", "availableApertureValues", "supportedApertureValues"]
        var found: [Float] = []
        for key in keys {
            guard let any = Self.safeValue(device, key) else { continue }
            if let nums = any as? [NSNumber] {
                found = nums.map { $0.floatValue }
                break
            }
            if let vals = any as? [Float] {
                found = vals
                break
            }
        }
        found = found.filter { $0 > 0.4 && $0 < 32 }.sorted()
        let current = device.lensAperture
        DispatchQueue.main.async {
            self.apertureStops = found
            self.currentAperture = current > 0 ? current : found.first
        }
    }

    private static func applyAperture(_ device: AVCaptureDevice, _ value: Float) {
        let sel = NSSelectorFromString("setAperture:")
        guard device.responds(to: sel) else { return }
        do {
            try device.lockForConfiguration()
            device.perform(sel, with: NSNumber(value: value))
            device.unlockForConfiguration()
        } catch {}
    }

    private static func safeValue(_ object: NSObject, _ key: String) -> Any? {
        guard object.responds(to: Selector(key)) else { return nil }
        return object.value(forKey: key)
    }
}

extension CameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        lock.lock()
        let cb = committed
        committed = nil
        lock.unlock()
        if let cb {
            DispatchQueue.main.async { cb() }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil {
            finishCapture(nil)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        finishCapture(photo.fileDataRepresentation())
    }
}
