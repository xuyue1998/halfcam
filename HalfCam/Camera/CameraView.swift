import SwiftUI
import UIKit

struct CameraView: View {
    @Environment(AppModel.self) private var model
    @State private var trail: CGFloat = 0
    @State private var counterKick: CGFloat = 0
    @State private var curtain: CGFloat = 0
    @State private var showLoader = false
    @State private var showUnload = false
    @State private var rewindProgress: CGFloat = 0
    @State private var rewindDoneFlash = false
    @State private var ev: Float = 0
    @State private var evAtStart: Float = 0
    @State private var lastEVTick: Int = 0
    @State private var draggingEV = false
    @State private var emptyShutterFlash = false
    @State private var blackHintFlash = false
    @State private var shutterDown = false
    @State private var sprocketWarm = false
    @State private var holeFrames: [TutorialHole: [CGRect]] = [:]
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        GeometryReader { geo in
            let barH: CGFloat = 98
            let extraDial: CGFloat = model.camera.apertureStops.isEmpty ? 0 : 36
            let mDialH: CGFloat = model.manualMode && !extraLocked ? (108 + extraDial) : 0
            let topReserve: CGFloat = 64
            let counterH: CGFloat = 70
            let maxFinderH = max(120, geo.size.height - topReserve - barH - mDialH - counterH)
            let finderW = min(geo.size.width - 32, 360, maxFinderH * 3 / 4)
            let finderH = finderW * 4 / 3
            ZStack(alignment: .bottom) {
                LeatherBody()
                    .equatable()
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                    Spacer(minLength: 4)
                    finderStack(finderW: finderW, finderH: finderH)
                    if model.manualMode, !extraLocked {
                        exposureStrip
                            .frame(width: finderW + 18)
                            .padding(.top, 8)
                    }
                    Spacer(minLength: 4)
                    counterRow
                    Color.clear.frame(height: barH)
                }
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                if showCoachMask, let hole = tutorialHole {
                    let frames = holeFrames[hole] ?? []
                    if !frames.isEmpty {
                        TutorialSpotlight(
                            frames: frames,
                            hole: hole,
                            caption: tutorialCaption
                        )
                    }
                }
                if showCoachMask, !finderHint.isEmpty, let finder = holeFrames[.finder]?.first, !finder.isNull {
                    ChromeToast(text: finderHint)
                        .position(x: finder.midX, y: finder.midY)
                        .allowsHitTesting(false)
                }
            }
        }
        .coordinateSpace(name: "cameraBody")
        .onPreferenceChange(HoleFrameKey.self) { holeFrames = $0 }
        .statusBarHidden()
        .overlay {
            ZStack {
                if model.showDarkbox {
                    DarkboxView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.move(edge: .bottom))
                }
                if model.showAlbum {
                    AlbumView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.move(edge: .bottom))
                }
                if model.showSettings {
                    SettingsPanel()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.move(edge: .bottom))
                }
                if showUnload {
                    unloadConfirm
                }
                if !model.exportNotice.isEmpty {
                    VStack {
                        Spacer()
                        ChromeToast(text: model.exportNotice)
                            .padding(.bottom, 36)
                    }
                    .allowsHitTesting(false)
                }
                if sprocketWarm {
                    FilmSprocketFrame(rebates: ["1", "1A"]) {
                        Color.clear.frame(width: 320, height: 120)
                    }
                    .frame(width: 320, height: 180)
                    .opacity(0.01)
                    .offset(y: 2000)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.camera.refreshPermission()
                syncCamera()
                UIApplication.shared.isIdleTimerDisabled = true
            } else if phase == .background {
                model.camera.stop()
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            model.camera.flashOn = model.flashOn
            model.camera.setProRAW(model.proRAW)
            syncCamera()
            model.applyExposureMode()
            if model.pendingLoadRoll {
                model.pendingLoadRoll = false
                openLoaderIfAllowed()
            }
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                sprocketWarm = true
                try? await Task.sleep(for: .milliseconds(400))
                sprocketWarm = false
            }
        }
        .onChange(of: model.camera.syncedFocusLens) { _, value in
            guard let value else { return }
            model.focusLens = value
        }
        .onChange(of: model.showDarkroom) { _, on in
            if on {
                model.camera.stop()
            } else {
                model.camera.start()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            Soundboard.shared.stop("rewind")
            Haptics.shared.grainStop(fade: false)
        }
        .fullScreenCover(isPresented: $showLoader) {
            LoadRollView()
                .environment(model)
                .interactiveDismissDisabled()
        }
        .onChange(of: showLoader) { _, on in
            model.presentingLoadRoll = on
        }
        .onChange(of: model.pendingLoadRoll) { _, on in
            if on {
                model.pendingLoadRoll = false
                openLoaderIfAllowed()
            }
        }
    }

    private var canForceUnload: Bool {
        guard let roll = model.currentRoll else { return false }
        if model.tutorialLocked { return false }
        if roll.shotCount == 0 { return true }
        if model.strictMode, !roll.isFull { return false }
        return true
    }

    private var needsLoad: Bool { model.currentRoll == nil }

    private var needsWind: Bool {
        guard let roll = model.currentRoll else { return false }
        return roll.canWind && !model.isCapturing
    }

    private var needsShoot: Bool {
        model.currentRoll?.canShoot == true && !model.isCapturing
    }

    private var needsRewind: Bool {
        model.currentRoll?.state == .needsRewind
    }

    private var extraLocked: Bool { model.tutorialLocked }

    private var needsDarkbox: Bool {
        model.tutorialLocked
            && model.currentRoll == nil
            && !model.darkboxRolls.isEmpty
    }

    private var showFirstRollMask: Bool {
        model.tutorialLocked
            && !showLoader
            && !model.showDarkbox
            && !model.showAlbum
            && !model.showSettings
            && !model.showDarkroom
    }

    private var showSecondRollMask: Bool {
        model.hasCompletedOnboarding
            && !model.tutorialLocked
            && !showLoader
            && !model.showDarkbox
            && !model.showAlbum
            && !model.showSettings
            && !model.showDarkroom
            && (model.currentRoll?.canShoot == true || model.isCapturing)
            && (!model.hasSeenFlashHint || !model.hasSeenManualHint || !model.hasSeenEVHint)
    }

    private var showCoachMask: Bool { showFirstRollMask || showSecondRollMask }

    private var tutorialHole: TutorialHole? {
        if showFirstRollMask {
            if model.isCapturing { return .shutter }
            if needsRewind { return .rewind }
            if needsDarkbox { return .darkbox }
            if needsLoad { return .load }
            if needsWind { return .wind }
            if needsShoot { return .shutter }
            return nil
        }
        if showSecondRollMask {
            if !model.hasSeenFlashHint { return .flash }
            if !model.hasSeenManualHint { return .manual }
            if !model.hasSeenEVHint { return .ev }
        }
        return nil
    }

    private var tutorialCaption: String {
        switch tutorialHole {
        case .load: L("打开后盖，装入胶片")
        case .wind: L("转过片轮")
        case .shutter: L("按下快门")
        case .rewind: L("转动倒片")
        case .darkbox: L("送到暗房")
        case .flash: L("补光")
        case .manual: L("拨到 M")
        case .ev: L("上拨曝光")
        case .finder, .none: ""
        }
    }

    private var shouldShowWinderCoach: Bool {
        needsWind && (showFirstRollMask || emptyShutterFlash)
    }

    private var shouldShowShutterCoach: Bool {
        needsShoot && showFirstRollMask
    }

    private var shouldShowFlashCoach: Bool {
        tutorialHole == .flash
    }

    private var shouldShowManualCoach: Bool {
        tutorialHole == .manual
    }

    private var shouldShowEVCoach: Bool {
        tutorialHole == .ev
    }

    private var finderHint: String {
        if model.camera.cameraDenied { return "" }
        if rewindDoneFlash { return L("已倒片") }
        if needsRewind { return L("请倒片") }
        if emptyShutterFlash { return L("先过片") }
        if blackHintFlash { return L("拍满才能洗") }
        if draggingEV && !model.hasSeenEVHint { return L("上拨曝光") }
        return ""
    }

    private func openLoaderIfAllowed() {
        guard model.currentRoll == nil else { return }
        if model.tutorialInProgress {
            withAnimation(.easeOut(duration: 0.28)) {
                model.showDarkbox = true
            }
            return
        }
        if model.isOnboarding {
            Task {
                let ok = await model.camera.ensureAuthorized()
                if ok {
                    showLoader = true
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(url)
                }
            }
            return
        }
        if model.camera.cameraDenied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            return
        }
        showLoader = true
    }

    private var unloadConfirm: some View {
        let force = canForceUnload
        let remaining = model.currentRoll?.remaining ?? 0
        let shot = model.currentRoll?.shotCount ?? 0
        return ChromeConfirm(
            title: force ? L("卸下这卷？") : L("拍满才能卸"),
            message: force
                ? L("已拍 \(shot) 格，剩下 \(remaining) 格将作废。")
                : L("还剩 \(remaining) 格，拍满才能卸。"),
            confirmTitle: force ? L("卸卷并送去显影") : L("好"),
            cancelTitle: force ? L("取消") : nil,
            confirm: {
                showUnload = false
                if force { model.forceUnload() }
            },
            cancel: { showUnload = false }
        )
    }

    private func syncCamera() {
        if model.showDarkroom {
            model.camera.stop()
        } else {
            model.camera.start()
        }
    }

    private func finderStack(finderW: CGFloat, finderH: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: HalfRadius.finder, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.55), Color(white: 0.22), Color(white: 0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: finderW + 18, height: finderH + 18)
                .shadow(color: .black.opacity(0.55), radius: 10, y: 4)
                .overlay {
                    HStack {
                        BrassInlay()
                            .padding(.vertical, 10)
                            .padding(.leading, 5)
                        Spacer(minLength: 0)
                        BrassInlay()
                            .padding(.vertical, 10)
                            .padding(.trailing, 5)
                    }
                }
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.black)
                .frame(width: finderW + 2, height: finderH + 2)
            ViewfinderView(
                session: model.camera,
                hasFilm: model.currentRoll != nil,
                hint: finderHint,
                trail: trail,
                curtain: curtain,
                allowTapFocus: !model.manualMode || model.focusAuto,
                cameraDenied: model.camera.cameraDenied,
                    onEmptyTap: {
                    openLoaderIfAllowed()
                    Haptics.shared.latch()
                },
                onPermissionTap: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    Haptics.shared.chrome()
                }
            )
            .frame(width: finderW, height: finderH)
            .clipShape(RoundedRectangle(cornerRadius: 1, style: .continuous))
            .overlay(alignment: .bottom) {
                if model.camera.lensStops.count > 1 || model.camera.macroControlVisible {
                    lensStops
                        .padding(.bottom, 10)
                        .animation(nil, value: model.camera.macroControlVisible)
                }
            }
            .overlay(alignment: .topTrailing) {
                if model.manualMode {
                    Text("M")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(holeAnchor(.finder))
    }

    private var lensStops: some View {
        HStack(spacing: 7) {
            ForEach(model.camera.lensStops) { stop in
                let on = abs(model.camera.currentZoom - stop.factor) < 0.08
                Button {
                    model.camera.setZoom(stop.factor)
                    Haptics.shared.chrome()
                } label: {
                    VStack(spacing: 1) {
                        Text(stop.zoomLabel)
                            .font(.system(size: on ? 12 : 11, weight: on ? .bold : .medium, design: .monospaced))
                        Text(stop.mmLabel)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .opacity(on ? 0.72 : 0.55)
                    }
                    .foregroundStyle(on ? Color(white: 0.12) : Color.white.opacity(0.9))
                      .frame(width: on ? 48 : 40, height: 32)
                      .background {
                          Capsule()
                              .fill(on ? Color(white: 0.88) : Color.black.opacity(0.46))
                              .overlay(Capsule().stroke(Color.white.opacity(on ? 0 : 0.22), lineWidth: 0.6))
                      }
                  }
                  .buttonStyle(.plain)
            }
            if model.camera.macroControlVisible {
                Button {
                    model.camera.toggleMacroControl()
                    Haptics.shared.chrome()
                } label: {
                    Image(systemName: model.camera.macroLocked ? "camera.macro.slash" : "camera.macro")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            model.camera.macroLocked
                                ? Color.white.opacity(0.9)
                                : Color(red: 1, green: 0.84, blue: 0.18)
                        )
                        .frame(width: 32, height: 32)
                        .background {
                            Capsule()
                                .fill(Color.black.opacity(0.55))
                                .overlay(Capsule().stroke(
                                    model.camera.macroLocked
                                        ? Color.white.opacity(0.22)
                                        : Color(red: 1, green: 0.84, blue: 0.18).opacity(0.7),
                                    lineWidth: 0.6
                                ))
                        }
                }
                .buttonStyle(.plain)
                .animation(nil, value: model.camera.macroLocked)
                .accessibilityLabel(L("自动微距"))
                .transition(.identity)
            }
        }
        .animation(nil, value: model.camera.macroControlVisible)
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            rewindCrank
                .frame(width: 56, height: 56, alignment: .leading)
            Spacer(minLength: 0)
            nameplate
            Spacer(minLength: 0)
            flashLamp
                .frame(width: 56, height: 56, alignment: .trailing)
        }
        .frame(height: 56)
    }

    private var nameplate: some View {
        let empty = model.currentRoll == nil
        let title: String = {
            if let roll = model.currentRoll {
                return FilmCatalog.recipe(id: roll.filmId).name
            }
            return "NO FILM"
        }()
        let paid = model.tier != .free
        let ink: Color = {
            if empty {
                return paid ? HalfColor.brassDeep : Color(white: 0.32)
            }
            return Color(white: 0.12)
        }()
        return Text(title)
            .font(.system(size: 13, weight: .semibold, design: empty ? .monospaced : .serif))
            .foregroundStyle(ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: HalfRadius.latch, style: .continuous)
                    .fill(HalfChrome.memberFill(model.tier))
                    .overlay(
                        RoundedRectangle(cornerRadius: HalfRadius.latch, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard !extraLocked else { return }
                withAnimation(.easeOut(duration: 0.28)) {
                    model.showSettings = true
                }
                Soundboard.shared.play("back")
                Haptics.shared.latch()
            }
    }

    private var rewindCrank: some View {
        let active = model.currentRoll?.state == .needsRewind
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(active ? 0.22 : 0), lineWidth: 3)
                .frame(width: 54, height: 54)
            Circle()
                .trim(from: 0, to: rewindProgress)
                .stroke(HalfColor.enamel.opacity(0.95), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(-90))
            RewindKnobView(
                enabled: active,
                onTick: { speed in
                    Soundboard.shared.play("tick")
                    Haptics.shared.tooth(speed: speed)
                },
                onProgress: { p in
                    rewindProgress = p
                },
                onComplete: { finishRewind() }
            )
            .frame(width: 40, height: 40)
            if active, rewindProgress < 0.02, showFirstRollMask || !model.hasSeenRewindHint {
                WinderCoachMark(diameter: 54)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 54, height: 54)
        .background(holeAnchor(.rewind))
        .frame(width: 56, height: 56, alignment: .leading)
    }

    private func finishRewind() {
        Soundboard.shared.stop("rewind")
        Haptics.shared.grainStop(fade: false)
        Haptics.shared.thud()
        Haptics.shared.swell()
        counterKick = 1
        rewindDoneFlash = true
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) { counterKick = 0 }
        model.markRewindHint()
        model.rewind()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            rewindProgress = 0
            try? await Task.sleep(for: .milliseconds(700))
            rewindDoneFlash = false
        }
    }

    private var flashLamp: some View {
        Button {
            model.flashOn.toggle()
            model.camera.flashOn = model.flashOn
            model.applyFeel()
            model.markFlashHint()
            Haptics.shared.chrome()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(model.flashOn ? 0.5 : 0))
                    .frame(width: 32, height: 32)
                    .blur(radius: 6)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.55), Color(white: 0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 30, height: 30)
                Circle()
                    .stroke(
                        LinearGradient(colors: [Color(white: 0.82), Color(white: 0.35)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.6
                    )
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: model.flashOn
                                ? [Color(red: 1, green: 0.96, blue: 0.78), Color(red: 0.88, green: 0.58, blue: 0.1)]
                                : [Color(white: 0.28), Color(white: 0.1)],
                            center: UnitPoint(x: 0.38, y: 0.32),
                            startRadius: 1,
                            endRadius: 11
                        )
                    )
                    .frame(width: 18, height: 18)
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .opacity(extraLocked ? 0.45 : 1)
        .allowsHitTesting(!extraLocked)
        .background(holeAnchor(.flash))
        .modifier(PulseScaleModifier(amount: 1.08, active: shouldShowFlashCoach, repeats: true))
    }

    private var counterRow: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                darkboxWindow
                counter
                albumWindow
            }
            Text(String(format: "%+.1f EV", ev))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.62))
        }
    }

    private var darkboxWindow: some View {
        let filled = !model.darkboxRolls.isEmpty
        let locked = extraLocked && model.currentRoll != nil
        return Button {
            guard !locked else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                model.showDarkbox = true
            }
            model.markDarkboxHint()
            Haptics.shared.chrome()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.08))
                    .frame(width: 36, height: 38)
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(white: 0.38), lineWidth: 0.8)
                    .frame(width: 36, height: 38)
                if filled {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.86, green: 0.58, blue: 0.18),
                                    Color(red: 0.52, green: 0.28, blue: 0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 18, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(Color(white: 0.22), lineWidth: 0.6)
                        .frame(width: 16, height: 20)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.45 : 1)
        .allowsHitTesting(!locked)
        .background(holeAnchor(.darkbox))
        .modifier(PulseScaleModifier(amount: 1.08, active: tutorialHole == .darkbox, repeats: true))
    }

    private var albumWindow: some View {
        let filled = !model.albumRolls.isEmpty
        let locked = extraLocked
        return Button {
            guard !locked else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                model.showAlbum = true
            }
            model.markAlbumHint()
            Haptics.shared.chrome()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.08))
                    .frame(width: 36, height: 38)
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(white: 0.38), lineWidth: 0.8)
                    .frame(width: 36, height: 38)
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(filled ? Color(white: 0.72) : Color(white: 0.18))
                            .frame(width: 6, height: 18)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.45 : 1)
        .allowsHitTesting(!locked)
    }

    private var counter: some View {
        let cap = model.currentRoll.map { String(format: "%02d", $0.capacity) }
        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.12, green: 0.02, blue: 0.02))
                .frame(width: 82, height: 38)
            VStack(spacing: 0) {
                SevenSegment(text: model.counterText)
                if let cap {
                    Text("/\(cap)")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(red: 1, green: 0.22, blue: 0.16).opacity(0.55))
                }
            }
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.clear, Color.black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 82, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .allowsHitTesting(false)
        }
        .frame(width: 82, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color(white: 0.38), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        .offset(y: counterKick * -5)
        .scaleEffect(x: 1, y: 1 - counterKick * 0.08)
    }

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(spacing: 10) {
                amLever
                backCover
            }
            .frame(width: 88, height: 88)
            Spacer(minLength: 0)
            ZStack {
                shutterButton
                if shouldShowEVCoach, !draggingEV {
                    EvCoachMark()
                        .offset(x: -54, y: -6)
                        .allowsHitTesting(false)
                }
                if draggingEV || abs(ev) > 0.05 {
                    evMeter
                        .offset(x: -52)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: 88, height: 88)
            Spacer(minLength: 0)
            ZStack {
                WinderView(
                    enabled: model.currentRoll?.canWind == true && !model.isCapturing,
                    onTick: { speed in
                        Soundboard.shared.play("tick")
                        Haptics.shared.tooth(speed: speed)
                    },
                    onAdvanced: {
                        model.wind()
                        counterKick = 1
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) { counterKick = 0 }
                        var reset = Transaction()
                        reset.disablesAnimations = true
                        withTransaction(reset) { trail = 0 }
                        withAnimation(.linear(duration: 0.08)) { trail = 1 }
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(80))
                            var t = Transaction()
                            t.disablesAnimations = true
                            withTransaction(t) { trail = 0 }
                        }
                    }
                )
                .frame(width: 88, height: 88)
                .opacity(needsWind ? 1 : (model.currentRoll == nil ? 0.28 : 0.42))
                if shouldShowWinderCoach {
                    WinderCoachMark(diameter: 86)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: 88, height: 88)
            .background(holeAnchor(.wind))
            .modifier(PulseScaleModifier(amount: 1.06, active: shouldShowWinderCoach, repeats: true))
        }
    }

    private var backCover: some View {
        let empty = model.currentRoll == nil
        let hideUnload = model.tutorialLocked && !empty
        return Button {
            if empty {
                openLoaderIfAllowed()
                Haptics.shared.latch()
            } else if !hideUnload, model.currentRoll?.state == .shooting {
                Haptics.shared.latch()
                showUnload = true
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: HalfRadius.plate, style: .continuous)
                    .fill(HalfChrome.steelFill)
                    .frame(width: 64, height: 28)
                RoundedRectangle(cornerRadius: HalfRadius.plate, style: .continuous)
                    .stroke(HalfColor.strokeBright.opacity(0.7), lineWidth: HalfColor.hairline)
                    .frame(width: 64, height: 28)
                HStack(spacing: 8) {
                    Capsule()
                        .fill(HalfChrome.latchFill)
                        .frame(width: 20, height: 7)
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        .rotationEffect(.degrees(empty ? -32 : 0), anchor: .leading)
                    Text(empty ? L("装卷") : (hideUnload ? L("已装卷") : L("卸卷")))
                        .font(HalfType.mono(10, weight: .semibold))
                        .foregroundStyle(HalfColor.ink.opacity(0.92))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 72, height: 32)
        .modifier(PulseScaleModifier(amount: 1.04, active: empty && !model.tutorialInProgress, repeats: extraLocked))
        .opacity(hideUnload ? 0.55 : 1)
        .allowsHitTesting(empty || !hideUnload)
        .background(holeAnchor(.load))
    }

    private var evMeter: some View {
        VStack(spacing: 3) {
            ForEach([2, 1, 0, -1, -2], id: \.self) { step in
                Circle()
                    .fill(evTickOn(step) ? Color.white : Color(white: 0.35))
                    .frame(width: step == 0 ? 6 : 4, height: step == 0 ? 6 : 4)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
    }

    private func evTickOn(_ step: Int) -> Bool {
        let current = Int((ev * 3).rounded())
        if step == 0 { return current == 0 }
        if step > 0 { return current >= step * 3 }
        return current <= step * 3
    }

    private var shutterButton: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 3.5
                )
                .frame(width: 76, height: 76)
            Group {
                if model.currentRoll?.canShoot == true {
                    Circle().fill(HalfChrome.enamelFill)
                } else {
                    Circle().fill(HalfColor.enamel.opacity(0.35))
                }
            }
            .frame(width: 58, height: 58)
            .scaleEffect(shutterDown || model.isCapturing ? 0.9 : 1)
            ShutterHitView(
                onDown: {
                    shutterDown = true
                },
                onPress: {
                    Task { await pressShutter() }
                },
                onRelease: {
                    if !model.isCapturing { shutterDown = false }
                },
                onEVChanged: { translation in
                    if extraLocked { return }
                    shutterDown = false
                    if !draggingEV {
                        draggingEV = true
                        evAtStart = ev
                        lastEVTick = Int((ev * 3).rounded())
                    }
                    let raw = evAtStart + Float(-translation) / 22
                    var next = (raw * 3).rounded() / 3
                    next = min(2, max(-2, next))
                    if abs(next) < 0.12 { next = 0 }
                    let tick = Int((next * 3).rounded())
                    if tick != lastEVTick {
                        lastEVTick = tick
                        Haptics.shared.detent(zero: next == 0)
                    }
                    ev = next
                    model.setEV(ev, dragging: true)
                },
                onEVEnded: {
                    guard draggingEV else { return }
                    draggingEV = false
                    model.markEVHint()
                    if abs(ev) < 0.12 { ev = 0 }
                    model.setEV(ev, dragging: false)
                },
                onResetEV: {
                    ev = 0
                    model.setEV(0)
                    Haptics.shared.detent(zero: true)
                }
            )
            .frame(width: 76, height: 76)
            .allowsHitTesting(!model.isCapturing)
        }
        .background(holeAnchor(.shutter, .ev))
        .modifier(PulseScaleModifier(amount: 1.08, active: shouldShowShutterCoach, repeats: true))
    }

    private func pressShutter() async {
        guard !model.isCapturing else { return }
        guard let roll = model.currentRoll, roll.canShoot else {
            Soundboard.shared.play("empty")
            Haptics.shared.empty()
            emptyShutterFlash = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1200))
                emptyShutterFlash = false
            }
            shutterDown = false
            return
        }
        model.isCapturing = true
        Soundboard.shared.play("shutter")
        Haptics.shared.shutter()
        let showBlack = !model.hasSeenBlackHint
        let willFill = roll.shotCount + 1 >= roll.capacity
        var hard = Transaction()
        hard.disablesAnimations = true
        withTransaction(hard) {
            curtain = 1
            shutterDown = true
        }
        if let data = await model.camera.capture(onCommitted: {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeOut(duration: 0.1)) { curtain = 0 }
            }
        }) {
            model.commitShot(data)
            var kick = Transaction()
            kick.disablesAnimations = true
            withTransaction(kick) { counterKick = 1 }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) { counterKick = 0 }
            if model.hasCompletedOnboarding, !showSecondRollMask {
                model.markFlashHint()
                model.markManualHint()
                model.markEVHint()
            }
        }
        if curtain > 0.001 {
            withAnimation(.easeOut(duration: 0.1)) { curtain = 0 }
        }
        if willFill {
            Haptics.shared.detent()
        }
        model.isCapturing = false
        shutterDown = false
        if showBlack {
            blackHintFlash = true
            model.markBlackHint()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1600))
                blackHintFlash = false
            }
        }
    }

    private var amLever: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                model.setManualMode(!model.manualMode)
            }
            model.markManualHint()
            Haptics.shared.chrome()
        } label: {
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 72, height: 32)
                Capsule()
                    .stroke(Color(white: 0.32), lineWidth: 0.8)
                    .frame(width: 72, height: 32)
                HStack(spacing: 0) {
                    Text("A")
                        .frame(width: 30)
                        .foregroundStyle(model.manualMode ? Color(white: 0.38) : Color.white)
                    Text("M")
                        .frame(width: 30)
                        .foregroundStyle(model.manualMode ? Color.white : Color(white: 0.38))
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.82), Color(white: 0.42)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
                    .frame(width: 24, height: 24)
                    .offset(x: model.manualMode ? 16 : -16)
            }
            .frame(width: 72, height: 32)
        }
        .buttonStyle(.plain)
        .opacity(extraLocked ? 0.45 : 1)
        .allowsHitTesting(!extraLocked)
        .background(holeAnchor(.manual))
        .modifier(PulseScaleModifier(amount: 1.06, active: shouldShowManualCoach, repeats: true))
    }

    private var exposureStrip: some View {
        VStack(spacing: 8) {
            dialRow(mark: "ISO", auto: model.isoAuto, onAuto: { model.setISOAuto() }) {
                DialRing(
                    labels: ISOStop.allCases.map(\.title),
                    selected: model.isoAuto ? -1 : (ISOStop.allCases.firstIndex(where: { $0.rawValue == model.isoValue }) ?? 3)
                ) { i in
                    model.setISO(ISOStop.allCases[i].rawValue)
                }
            }
            dialRow(mark: "S", auto: model.shutterAuto, onAuto: { model.setShutterAuto() }) {
                DialRing(
                    labels: ShutterSpeed.allCases.map(\.title),
                    selected: model.shutterAuto ? -1 : (ShutterSpeed.allCases.firstIndex(of: model.shutter) ?? 7)
                ) { i in
                    model.setShutter(ShutterSpeed.allCases[i])
                }
            }
            if !model.camera.apertureStops.isEmpty {
                dialRow(mark: "f", auto: false, onAuto: nil) {
                    DialRing(
                        labels: model.camera.apertureStops.map { stop in
                            String(format: "f/%.1f", stop).replacingOccurrences(of: ".0", with: "")
                        },
                        selected: model.camera.apertureStops.firstIndex(where: {
                            abs((model.aperture ?? model.camera.currentAperture ?? 0) - $0) < 0.08
                        }) ?? -1
                    ) { i in
                        model.setAperture(model.camera.apertureStops[i])
                    }
                }
            }
            HStack(spacing: 6) {
                Text("F")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.45))
                    .frame(width: 28, alignment: .leading)
                MetalSelector(labels: ["A"], selected: model.focusAuto ? 0 : -1) { _ in
                    model.setFocusAuto()
                }
                .frame(width: 34, height: 26)
                focusBar
                    .frame(minWidth: 0, maxWidth: .infinity)
                Text(model.focusAuto ? "A" : model.focusDistanceLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(white: 0.7))
                    .frame(width: 44, alignment: .trailing)
                    .onTapGesture {
                        model.toggleFocusAuto()
                        Haptics.shared.chrome()
                    }
            }
            .frame(height: 28)
        }
    }

    private func dialRow<Content: View>(
        mark: String,
        auto: Bool,
        onAuto: (() -> Void)?,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack(spacing: 6) {
            Text(mark)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.45))
                .frame(width: 28, alignment: .leading)
            Group {
                if let onAuto {
                    MetalSelector(labels: ["A"], selected: auto ? 0 : -1) { _ in
                        onAuto()
                    }
                } else {
                    Color.clear
                }
            }
            .frame(width: 34, height: 26)
            control()
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(height: 28)
    }

    private var focusBar: some View {
        let minF = model.camera.currentMinFocusMeters
        let ticks = CameraSession.focusTicks(minFocus: minF)
        return VStack(spacing: 2) {
            GeometryReader { geo in
                let track = max(0, geo.size.width - 10)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(white: 0.18))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.white.opacity(model.focusAuto ? 0.25 : 0.7))
                        .frame(width: 10, height: 16)
                        .offset(x: CGFloat(model.focusLens) * track)
                    ForEach(Array(ticks.enumerated()), id: \.offset) { _, tick in
                        Rectangle()
                            .fill(Color(white: 0.55))
                            .frame(width: 1, height: 6)
                            .offset(x: tick.0 * track + 4)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let p = Float(min(max(value.location.x / geo.size.width, 0), 1))
                            model.setFocusLens(p)
                        }
                )
            }
            .frame(height: 16)
            HStack {
                Text(ticks.first?.1 ?? CameraSession.formatFocus(minF))
                Spacer(minLength: 0)
                Text(ticks.last?.1 ?? "∞")
            }
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .foregroundStyle(Color(white: 0.5))
        }
        .frame(height: 28)
    }

    private func holeAnchor(_ holes: TutorialHole...) -> some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named("cameraBody"))
            Color.clear.preference(
                key: HoleFrameKey.self,
                value: Dictionary(uniqueKeysWithValues: holes.map { ($0, [frame]) })
            )
        }
    }

}

struct DialRing: View {
    var labels: [String]
    var selected: Int
    var pick: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(labels.indices, id: \.self) { i in
                        let on = i == selected
                        Button {
                            pick(i)
                            Haptics.shared.detent()
                        } label: {
                            Text(labels[i])
                                .font(.system(size: 11, weight: on ? .bold : .regular, design: .monospaced))
                                .foregroundStyle(on ? Color.white : Color(white: 0.45))
                                .frame(width: 36, height: 26)
                                .background {
                                    if on {
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(white: 0.82), Color(white: 0.42)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(3)
            }
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.45))
                    .overlay(Capsule().stroke(Color(white: 0.32), lineWidth: 0.8))
            )
            .onAppear { if selected >= 0 { proxy.scrollTo(selected, anchor: .center) } }
            .onChange(of: selected) { _, v in
                if v >= 0 { withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(v, anchor: .center) } }
            }
        }
    }
}

struct WinderCoachMark: View {
    var diameter: CGFloat = 86
    @State private var spin = false

    private let tip: CGFloat = 0.32

    var body: some View {
        let radius = diameter * 0.5
        let theta = tip * 2 * CGFloat.pi
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.4, dash: [3, 4]))
                .frame(width: diameter, height: diameter)
            Circle()
                .trim(from: 0.04, to: tip)
                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(-90))
            Image(systemName: "chevron.right")
                .font(.system(size: max(10, diameter * 0.13), weight: .bold))
                .foregroundStyle(Color.white.opacity(0.92))
                .rotationEffect(.degrees(Double(tip * 360)))
                .offset(x: sin(theta) * radius, y: -cos(theta) * radius)
        }
        .rotationEffect(.degrees(spin ? 360 : 0))
        .onAppear {
            guard !Haptics.reduceMotion else { return }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}

struct EvCoachMark: View {
    @State private var lift = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "chevron.up")
                .font(.system(size: 11, weight: .bold))
            Capsule()
                .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                .frame(width: 1.6, height: 18)
        }
        .foregroundStyle(Color.white.opacity(0.88))
        .offset(y: lift ? -5 : 2)
        .onAppear {
            guard !Haptics.reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                lift = true
            }
        }
    }
}

enum TutorialHole: Hashable {
    case load, wind, shutter, rewind, darkbox, flash, manual, ev, finder

    var pad: CGFloat {
        switch self {
        case .load: 6
        case .wind: 4
        case .shutter, .ev: 4
        case .rewind: 3
        case .darkbox: 10
        case .flash: 8
        case .manual: 10
        case .finder: 0
        }
    }

    var corner: CGFloat {
        switch self {
        case .load: 8
        case .wind, .shutter, .ev, .rewind, .flash: 32
        case .darkbox: 8
        case .manual: 16
        case .finder: 8
        }
    }

    var captionBelow: Bool {
        switch self {
        case .rewind, .flash: true
        default: false
        }
    }
}

struct HoleFrameKey: PreferenceKey {
    static var defaultValue: [TutorialHole: [CGRect]] = [:]

    static func reduce(value: inout [TutorialHole: [CGRect]], nextValue: () -> [TutorialHole: [CGRect]]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct HoleCutoutShape: Shape {
    var frames: [CGRect]
    var radius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        for frame in frames {
            path.addRoundedRect(in: frame, cornerSize: CGSize(width: radius, height: radius))
        }
        return path
    }
}

struct TutorialSpotlight: View {
    var frames: [CGRect]
    var hole: TutorialHole
    var caption: String

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .named("cameraBody")).origin
            let holes = frames.map { frame -> CGRect in
                var hole = frame.offsetBy(dx: -origin.x, dy: -origin.y)
                hole = hole.insetBy(dx: -self.hole.pad, dy: -self.hole.pad)
                return hole
            }
            let target = holes.min(by: { $0.height < $1.height }) ?? holes.first ?? .null
            ZStack {
                Color.black.opacity(0.58)
                    .clipShape(HoleCutoutShape(frames: holes, radius: hole.corner), style: FillStyle(eoFill: true))
                    .contentShape(HoleCutoutShape(frames: holes, radius: hole.corner), eoFill: true)
                    .highPriorityGesture(TapGesture())
                if !target.isNull, !target.isInfinite {
                    Text(caption)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.94))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                        .position(captionPoint(target, in: geo.size))
                        .allowsHitTesting(false)
                }
            }
        }
        .allowsHitTesting(true)
    }

    private func captionPoint(_ target: CGRect, in size: CGSize) -> CGPoint {
        let captionH: CGFloat = 32
        let gap: CGFloat = 14
        let x: CGFloat = {
            switch hole {
            case .rewind:
                return min(max(target.midX + 18, 72), size.width - 72)
            case .load:
                return min(max(target.maxX + 86, 110), size.width - 110)
            case .shutter, .ev:
                return min(max(target.midX, 88), size.width - 88)
            default:
                return min(max(target.midX, 72), size.width - 72)
            }
        }()
        let below = hole.captionBelow || target.minY < 64
        let y: CGFloat = {
            if hole == .load {
                return min(max(target.midY, 36), size.height - 36)
            }
            if hole == .shutter || hole == .ev {
                let above = target.minY - gap - captionH / 2
                return max(above, 96)
            }
            if below {
                return min(target.maxY + gap + captionH / 2, size.height - 36)
            }
            return max(target.minY - gap - captionH / 2, 36)
        }()
        return CGPoint(x: x, y: y)
    }
}

struct PulseScaleModifier: ViewModifier {
    var amount: CGFloat
    var active: Bool
    var pulses: Int = 3
    var repeats: Bool = false
    @State private var on = false
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && on ? amount : 1)
            .onAppear { startIfNeeded() }
            .onChange(of: active) { _, next in
                if next { startIfNeeded() } else { stop() }
            }
            .onDisappear { stop() }
    }

    private func startIfNeeded() {
        guard active, task == nil else { return }
        if Haptics.reduceMotion { return }
        task = Task { @MainActor in
            let count = repeats ? Int.max : pulses
            for _ in 0..<count {
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.45)) { on = true }
                try? await Task.sleep(for: .milliseconds(450))
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.45)) { on = false }
                try? await Task.sleep(for: .milliseconds(450))
            }
            task = nil
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        on = false
    }
}

struct LeatherBody: View, Equatable {
    static func == (lhs: LeatherBody, rhs: LeatherBody) -> Bool { true }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.13, blue: 0.11),
                    HalfColor.body,
                    Color(red: 0.05, green: 0.05, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Canvas { ctx, size in
                var rng = SeededRandom(0xC0FFEE)
                let count = 1400
                for i in 0..<count {
                    let x: CGFloat
                    if i % 3 == 0 {
                        x = rng.unit() < 0.5
                            ? rng.unit() * size.width * 0.18
                            : size.width * (0.82 + rng.unit() * 0.18)
                    } else {
                        x = rng.unit() * size.width
                    }
                    let y = rng.unit() * size.height
                    let w = 0.4 + rng.unit() * 1.8
                    let h = 0.25 + rng.unit() * 0.55
                    let a = 0.016 + rng.unit() * 0.045
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)),
                        with: .color(.white.opacity(a))
                    )
                }
            }
            .opacity(0.62)
            VStack(spacing: 0) {
                SteelBezel()
                Spacer()
            }
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct SevenSegment: View {
    var text: String
    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                Digit(char: ch)
            }
        }
    }
}

struct Digit: View {
    var char: Character
    private let on = HalfColor.segment
    private let off = Color(red: 0.32, green: 0.05, blue: 0.05)
    var body: some View {
        let segs = segments(char)
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let t: CGFloat = 3.2
            let inset: CGFloat = 1.5
            func horiz(_ y: CGFloat) -> Path {
                var p = Path()
                p.addRoundedRect(in: CGRect(x: inset + t * 0.4, y: y - t / 2, width: w - (inset + t * 0.4) * 2, height: t), cornerSize: CGSize(width: 1, height: 1))
                return p
            }
            func vert(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> Path {
                var p = Path()
                p.addRoundedRect(in: CGRect(x: x - t / 2, y: y0 + t * 0.3, width: t, height: y1 - y0 - t * 0.6), cornerSize: CGSize(width: 1, height: 1))
                return p
            }
            let paths: [(Int, Path)] = [
                (0, horiz(inset + t / 2)),
                (1, vert(w - inset - t / 2, inset, h / 2)),
                (2, vert(w - inset - t / 2, h / 2, h - inset)),
                (3, horiz(h - inset - t / 2)),
                (4, vert(inset + t / 2, h / 2, h - inset)),
                (5, vert(inset + t / 2, inset, h / 2)),
                (6, horiz(h / 2))
            ]
            for (i, path) in paths {
                ctx.fill(path, with: .color(segs.contains(i) ? on : off))
            }
        }
        .frame(width: 16, height: 24)
    }

    private func segments(_ c: Character) -> Set<Int> {
        switch c {
        case "0": [0, 1, 2, 3, 4, 5]
        case "1": [1, 2]
        case "2": [0, 1, 6, 4, 3]
        case "3": [0, 1, 6, 2, 3]
        case "4": [5, 6, 1, 2]
        case "5": [0, 5, 6, 2, 3]
        case "6": [0, 5, 6, 2, 3, 4]
        case "7": [0, 1, 2]
        case "8": [0, 1, 2, 3, 4, 5, 6]
        case "9": [0, 1, 2, 3, 5, 6]
        default: []
        }
    }
}
