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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        GeometryReader { geo in
            let barH: CGFloat = 98
            let extraDial: CGFloat = model.camera.apertureStops.isEmpty ? 0 : 36
            let mDialH: CGFloat = model.manualMode ? (108 + extraDial) : 0
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
                    if model.manualMode, !model.tutorialLocked {
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
            }
        }
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

    private var shouldShowWinderCoach: Bool {
        guard let roll = model.currentRoll else { return false }
        guard roll.canWind, !model.isCapturing else { return false }
        return model.tutorialLocked || !model.hasSeenHint || emptyShutterFlash
    }

    private var shouldShowShutterCoach: Bool {
        guard model.tutorialLocked, !model.isCapturing else { return false }
        return model.currentRoll?.canShoot == true
    }

    private var shouldShowSecondRollCoach: Bool {
        guard model.hasCompletedOnboarding, !model.tutorialLocked, !model.isCapturing else { return false }
        return model.currentRoll?.canShoot == true
    }

    private var shouldShowFlashCoach: Bool {
        shouldShowSecondRollCoach && !model.hasSeenFlashHint
    }

    private var shouldShowManualCoach: Bool {
        shouldShowSecondRollCoach && !model.hasSeenManualHint
    }

    private var shouldShowEVCoach: Bool {
        shouldShowSecondRollCoach && !model.hasSeenEVHint
    }

    private var finderHint: String {
        if model.camera.cameraDenied { return "" }
        if rewindDoneFlash { return L("已倒片") }
        if model.currentRoll?.state == .needsRewind { return L("请倒片") }
        if emptyShutterFlash { return L("先过片") }
        if blackHintFlash { return L("拍完看不见") }
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
            confirmTitle: force ? L("卸卷并送洗") : L("好"),
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.55), Color(white: 0.22), Color(white: 0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: finderW + 18, height: finderH + 18)
                .shadow(color: .black.opacity(0.55), radius: 10, y: 4)
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
                if model.camera.lensStops.count > 1 {
                    lensStops.padding(.bottom, 10)
                }
            }
        }
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
        }
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
        return Text(title)
            .font(.system(size: 13, weight: .semibold, design: empty ? .monospaced : .serif))
            .foregroundStyle(Color(white: empty ? 0.32 : 0.12))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.78), Color(white: 0.52), Color(white: 0.64)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            )
    }

    private var rewindCrank: some View {
        let active = model.currentRoll?.state == .needsRewind
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(active ? 0.22 : 0), lineWidth: 3)
                .frame(width: 54, height: 54)
            Circle()
                .trim(from: 0, to: rewindProgress)
                .stroke(Color.red.opacity(0.95), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
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
            .opacity(active ? 1 : 0.7)
            if active, rewindProgress < 0.02 {
                WinderCoachMark(diameter: 68)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 56, height: 56)
        .offset(x: -4)
    }

    private func finishRewind() {
        Soundboard.shared.stop("rewind")
        Haptics.shared.grainStop(fade: false)
        Haptics.shared.thud()
        Haptics.shared.swell()
        counterKick = 1
        rewindDoneFlash = true
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) { counterKick = 0 }
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
            .overlay(alignment: .bottom) {
                Text(L("补光"))
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .padding(.bottom, 1)
                    .opacity(shouldShowFlashCoach ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .opacity(model.tutorialLocked ? 0.35 : 1)
        .allowsHitTesting(!model.tutorialLocked)
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
        let locked = model.tutorialLocked && model.currentRoll != nil
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
            .overlay(alignment: .bottom) {
                Text(L("暗盒"))
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 2)
                    .opacity(model.hasSeenDarkboxHint ? 0 : 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.45 : 1)
        .allowsHitTesting(!locked)
    }

    private var albumWindow: some View {
        let filled = !model.albumRolls.isEmpty
        let locked = model.tutorialLocked
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
            .overlay(alignment: .bottom) {
                Text(L("相册"))
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 2)
                    .opacity(model.hasSeenAlbumHint ? 0 : 1)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.45 : 1)
        .allowsHitTesting(!locked)
    }

    private var counter: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.12, green: 0.02, blue: 0.02))
                .frame(width: 82, height: 38)
            HStack(spacing: 6) {
                SevenSegment(text: model.counterText)
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
                .opacity(model.currentRoll == nil ? 0.35 : 1)
                if shouldShowWinderCoach {
                    WinderCoachMark()
                        .allowsHitTesting(false)
                }
            }
            .frame(width: 88, height: 88)
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
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.22), Color(white: 0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 64, height: 28)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color(white: 0.42), lineWidth: 0.8)
                    .frame(width: 64, height: 28)
                HStack(spacing: 8) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.88), Color(white: 0.42)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 20, height: 7)
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        .rotationEffect(.degrees(empty ? -32 : 0), anchor: .leading)
                    Text(empty ? L("装卷") : (hideUnload ? L("已装卷") : L("卸卷")))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.82))
                }
            }
        }
        .buttonStyle(.plain)
        .modifier(PulseScaleModifier(amount: 1.04, active: empty && !model.tutorialInProgress, repeats: model.tutorialLocked))
        .opacity(hideUnload ? 0.55 : 1)
        .allowsHitTesting(empty || !hideUnload)
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
            Circle()
                .fill(Color(red: 0.72, green: 0.12, blue: 0.14).opacity(model.currentRoll?.canShoot == true ? 0.95 : 0.35))
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
                    if model.tutorialLocked { return }
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
        .overlay(alignment: .bottom) {
            Text(L("按下"))
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.78))
                .offset(y: 14)
                .opacity(shouldShowShutterCoach ? 1 : 0)
                .allowsHitTesting(false)
        }
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
            if model.hasCompletedOnboarding {
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
                    .frame(width: 64, height: 28)
                Capsule()
                    .stroke(Color(white: 0.32), lineWidth: 0.8)
                    .frame(width: 64, height: 28)
                HStack(spacing: 0) {
                    Text("A")
                        .frame(width: 26)
                        .foregroundStyle(model.manualMode ? Color(white: 0.38) : Color.white)
                    Text("M")
                        .frame(width: 26)
                        .foregroundStyle(model.manualMode ? Color.white : Color(white: 0.38))
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.82), Color(white: 0.42)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
                    .frame(width: 22, height: 22)
                    .offset(x: model.manualMode ? 14 : -14)
            }
            .frame(width: 64, height: 28)
            .overlay(alignment: .top) {
                Text(L("拨到 M"))
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .offset(y: -12)
                    .opacity(shouldShowManualCoach ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .opacity(model.tutorialLocked ? 0.35 : 1)
        .allowsHitTesting(!model.tutorialLocked)
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
                    .frame(width: 36, alignment: .trailing)
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
        GeometryReader { geo in
            let minF = model.camera.currentMinFocusMeters
            let ticks: [(CGFloat, String)] = [
                (CGFloat(CameraSession.slider(distance: 0.5, minFocus: minF)), "0.5"),
                (CGFloat(CameraSession.slider(distance: 1, minFocus: minF)), "1"),
                (CGFloat(CameraSession.slider(distance: 3, minFocus: minF)), "3"),
                (1.0, "∞")
            ]
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(white: 0.18))
                    .frame(height: 8)
                Capsule()
                    .fill(Color.white.opacity(model.focusAuto ? 0.25 : 0.7))
                    .frame(width: 10, height: 16)
                    .offset(x: CGFloat(model.focusLens) * max(0, geo.size.width - 10))
                ForEach(ticks, id: \.0) { tick in
                    Rectangle()
                        .fill(Color(white: 0.55))
                        .frame(width: 1, height: 6)
                        .offset(x: tick.0 * max(0, geo.size.width - 10) + 4)
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
        .frame(height: 22)
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
    var diameter: CGFloat = 104
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.4, dash: [3, 4]))
                .frame(width: diameter, height: diameter)
            Circle()
                .trim(from: 0.08, to: 0.42)
                .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(spin ? 360 : 0))
        }
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
                    Color(red: 0.08, green: 0.07, blue: 0.06),
                    Color(red: 0.05, green: 0.05, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Canvas { ctx, size in
                var rng = SeededRandom(0xC0FFEE)
                for _ in 0..<900 {
                    let x = rng.unit() * size.width
                    let y = rng.unit() * size.height
                    let s = rng.unit() * 1.6 + 0.4
                    let a = 0.018 + rng.unit() * 0.04
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                        with: .color(.white.opacity(a))
                    )
                }
            }
            .opacity(0.55)
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color(white: 0.34),
                        Color(white: 0.18),
                        Color(white: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 64)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black.opacity(0.55))
                        .frame(height: 3)
                }
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 28)
                }
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
    private let on = Color(red: 1, green: 0.22, blue: 0.16)
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
        .frame(width: 18, height: 28)
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
