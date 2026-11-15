import SwiftUI

enum RitualAct {
    case tank, chemistry, negative, strip
}

func developStageTitle(process: FilmProcess, phase: CGFloat, progress: Double) -> String {
    switch process {
    case .c41:
        if phase < 0.38 { return L("显影") }
        if phase < 0.72 { return L("漂白") }
        if progress < 1 { return L("水洗") }
        return L("定影完成")
    case .e6:
        if phase < 0.38 { return L("一浴") }
        if phase < 0.72 { return L("反转") }
        if progress < 1 { return L("彩显") }
        return L("定影完成")
    case .cine:
        if phase < 0.38 { return L("显影") }
        if phase < 0.72 { return L("停显") }
        if progress < 1 { return L("定影") }
        return L("水洗完成")
    case .bw:
        if phase < 0.38 { return L("显影") }
        if phase < 0.72 { return L("停显") }
        if progress < 1 { return L("定影") }
        return L("水洗完成")
    }
}

struct DarkroomView: View {
    @Environment(AppModel.self) private var model
    @State private var act: RitualAct = .tank
    @State private var tankY: CGFloat = 40
    @State private var cassetteY: CGFloat = -210
    @State private var cassetteFade: CGFloat = 1
    @State private var filmIn: CGFloat = 0
    @State private var lidLift: CGFloat = 64
    @State private var lidAngle: Double = 0
    @State private var liquid: CGFloat = 0
    @State private var chemPhase: CGFloat = 0
    @State private var tankScale: CGFloat = 1
    @State private var stripRise: CGFloat = 80
    @State private var revealedPairs = 0
    @State private var flippedPairs = 0
    @State private var negativeShown = 0
    @State private var negativeDensity: CGFloat = 0
    @State private var flash: CGFloat = 0
    @State private var keepError = ""
    @State private var dumping = false
    @State private var holdingKeepCard = false
    var rollId: UUID
    var roll: Roll

    private var live: Roll {
        model.rolls.first(where: { $0.id == rollId }) ?? roll
    }

    private var recipe: FilmRecipe {
        FilmCatalog.recipe(id: live.filmId)
    }

    private var pairs: [[Frame]] {
        stride(from: 0, to: live.frames.count, by: 2).map { i in
            Array(live.frames[i..<min(i + 2, live.frames.count)])
        }
    }

    private var allDeveloped: Bool {
        !live.frames.isEmpty && live.frames.allSatisfy { $0.developed && $0.posFileName != nil }
    }

    private var autoReveal: Int { pairs.count }

    private var showKeepCard: Bool {
        let eligible = !live.isTutorial && allDeveloped && flippedPairs >= pairs.count && !pairs.isEmpty
        if holdingKeepCard { return eligible }
        return eligible && !model.hasSeenKeepHint
    }

    var body: some View {
        ZStack {
            cavity
            VStack(spacing: 16) {
                if act == .tank || act == .chemistry { Spacer(minLength: 0) }
                if act == .tank || act == .chemistry {
                    tankAssembly
                        .scaleEffect(tankScale, anchor: .bottom)
                        .offset(y: tankY)
                }
                if act == .tank || act == .chemistry {
                    caption(
                        recipe.name,
                        sub: act == .tank
                            ? L("送进暗房")
                            : developStageTitle(process: recipe.process, phase: chemPhase, progress: model.developProgress)
                    )
                    Spacer(minLength: 0)
                }
            }
            .padding(.bottom, act == .strip || act == .negative ? 8 : 0)
            .allowsHitTesting(act == .tank || act == .chemistry)
            if act == .negative || act == .strip {
                stripAct
            }
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .task { await play() }
        .onDisappear {
            Soundboard.shared.stop("water")
            Haptics.shared.soakStop()
        }
    }

    private var cavity: some View {
        ZStack {
            Color(red: 0.05, green: 0.04, blue: 0.04)
            RadialGradient(
                colors: [
                    Color(red: 0.28, green: 0.04, blue: 0.04).opacity(safelight),
                    Color.clear
                ],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            Color(red: 1.0, green: 0.72, blue: 0.42).opacity(flash)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.7), value: act)
    }

    private var safelight: Double {
        switch act {
        case .tank: 0.55
        case .chemistry: 0.38
        case .negative: 0.18
        case .strip: 0.08
        }
    }

    private var tankAssembly: some View {
        ZStack {
            ChromeTank(
                cutaway: act != .tank,
                liquid: liquid,
                coil: act == .tank ? 0 : min(1, liquid + 0.12),
                leader: recipe.leaderColor,
                fluid: chemColor
            )
            if act == .tank {
                cassette
                    .offset(y: cassetteY)
                    .opacity(cassetteFade)
                leaderTongue
            }
            ChromeLid()
                .rotationEffect(.degrees(lidAngle))
                .offset(y: -100 - lidLift)
            if act == .chemistry {
                tempPlate
                    .offset(x: 88, y: 10)
                    .transition(.opacity)
            }
        }
        .frame(width: 220, height: 260)
    }

    private var cassette: some View {
        Image("FilmCassette")
            .resizable()
            .scaledToFit()
            .frame(width: 92, height: 56)
            .colorMultiply(recipe.silverCassette ? Color(white: 0.78) : Color.white)
            .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
    }

    private var leaderTongue: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 1,
            bottomTrailingRadius: 1,
            topTrailingRadius: 1
        )
            .fill(recipe.leaderColor)
            .frame(width: 16, height: 72 * max(0.08, filmIn))
            .overlay(alignment: .leading) {
                Rectangle().fill(Color.black.opacity(0.28)).frame(width: 2)
            }
            .offset(y: -52 + (1 - filmIn) * 18)
            .opacity(filmIn)
    }

    private var tempPlate: some View {
        BrassPlate(compact: true) {
            Text("38°C")
        }
    }

    private var stripAct: some View {
        VStack(spacing: 0) {
            Text(recipe.name)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(Color(white: 0.9))
                .padding(.top, 18)
            Text(act == .negative ? L("负片显现") : L("\(live.shotCount) 格"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(white: 0.5))
                .padding(.bottom, 12)
            ScrollView {
                LazyVStack(spacing: 12) {
                    let shown = act == .negative ? Array(pairs.enumerated().prefix(max(negativeShown, 1))) : Array(pairs.enumerated())
                    ForEach(shown, id: \.offset) { i, pair in
                        let strip = FilmSprocketFrame(rebates: pair.map { filmRebate($0.index) }) {
                            HStack(spacing: 2) {
                                ForEach(pair) { frame in
                                    stripCell(frame, pairIndex: i)
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(3 / 4, contentMode: .fit)
                                        .clipped()
                                }
                            }
                        }
                        if pair.count == 1 {
                            HStack(spacing: 0) {
                                strip
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        } else {
                            strip
                        }
                    }
                }
                .padding(.horizontal, 16)
                .offset(y: stripRise)
            }
            bottomBar
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 34)
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if flippedPairs >= pairs.count, !pairs.isEmpty {
            if showKeepCard {
                keepCard
            } else if allDeveloped || model.developProgress >= 1 {
                HStack(spacing: 10) {
                    if !live.isTutorial {
                        Button {
                            Haptics.shared.tick()
                            model.finishRitual(loadNew: true)
                        } label: {
                            HatchPlate(title: L("再拍一卷"), prominent: false)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        Haptics.shared.latch()
                        model.finishRitual()
                    } label: {
                        HatchPlate(title: L("放入相册"), prominent: true)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color(white: 0.7))
                        .scaleEffect(0.8)
                    Text(L("还在出片"))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(white: 0.55))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
        } else {
            Color.clear.frame(height: 36)
        }
    }

    private var keepCard: some View {
        VStack(spacing: 12) {
            Text(L("底片只在这台机里"))
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Color.white)
            Text(L("删除 App 会把没倒走的照片一起清掉。洗好的，可以先倒进系统相册。"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !keepError.isEmpty {
                Text(keepError)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(white: 0.72))
            }
            HStack(spacing: 10) {
                Button {
                    guard !dumping else { return }
                    model.markKeepHint()
                    Haptics.shared.tick()
                    model.finishRitual(autoDump: false)
                } label: {
                    HatchPlate(title: L("先不倒"), prominent: false)
                }
                .buttonStyle(.plain)
                .disabled(dumping)
                Button {
                    Task { await dumpThenFinish() }
                } label: {
                    HatchPlate(title: dumping ? L("正在倒出") : L("倒出这卷"), prominent: true)
                }
                .buttonStyle(.plain)
                .disabled(dumping)
            }
        }
        .padding(.top, 4)
    }

    private func dumpThenFinish() async {
        guard !dumping else { return }
        dumping = true
        holdingKeepCard = true
        model.markKeepHint()
        let outcome = await model.exportPrints(rollId: rollId)
        dumping = false
        switch outcome {
        case .saved, .noPrints:
            Haptics.shared.latch()
            model.finishRitual(autoDump: false)
        case .noPermission, .failed:
            keepError = PhotoExport.toast(outcome)
        }
    }

    private func caption(_ title: String, sub: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(Color(white: 0.88))
            Text(sub)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.55))
        }
    }

    private var chemColor: Color {
        switch recipe.process {
        case .bw:
            return chemPhase < 0.38
                ? Color(red: 0.72, green: 0.58, blue: 0.22)
                : (chemPhase < 0.72 ? Color(red: 0.55, green: 0.18, blue: 0.14) : Color(red: 0.62, green: 0.66, blue: 0.70))
        case .e6:
            return chemPhase < 0.38
                ? Color(red: 0.78, green: 0.42, blue: 0.12)
                : (chemPhase < 0.72 ? Color(red: 0.18, green: 0.42, blue: 0.55) : Color(red: 0.72, green: 0.28, blue: 0.18))
        case .cine:
            return chemPhase < 0.38
                ? Color(red: 0.72, green: 0.58, blue: 0.22)
                : (chemPhase < 0.72 ? Color(red: 0.18, green: 0.42, blue: 0.55) : Color(red: 0.62, green: 0.66, blue: 0.70))
        case .c41:
            return chemPhase < 0.38
                ? Color(red: 0.78, green: 0.42, blue: 0.12)
                : (chemPhase < 0.72 ? Color(red: 0.62, green: 0.14, blue: 0.10) : Color(red: 0.55, green: 0.62, blue: 0.68))
        }
    }

    private func stripCell(_ frame: Frame, pairIndex: Int) -> some View {
        let showNeg = pairIndex < negativeShown
        let flipped = pairIndex < flippedPairs
        let negOpacity = showNeg ? (flipped ? 0 : 0.28 + 0.72 * negativeDensity) : 0
        return ZStack {
            Color.black
            negativeImage(frame)
                .opacity(negOpacity)
            positiveImage(frame)
                .opacity(flipped ? 1 : 0)
        }
        .clipped()
    }

    @ViewBuilder
    private func negativeImage(_ frame: Frame) -> some View {
        FrameStill(roll: live, frame: frame, kind: .negative, empty: recipe.leaderColor)
    }

    @ViewBuilder
    private func positiveImage(_ frame: Frame) -> some View {
        FrameStill(roll: live, frame: frame, kind: .preview)
    }

    private func play() async {
        if live.state == .ready {
            await MainActor.run {
                act = .strip
                stripRise = 0
                tankScale = 0.42
                revealedPairs = pairs.count
                flippedPairs = pairs.count
                negativeShown = pairs.count
                negativeDensity = 1
            }
            return
        }
        if live.state == .waiting {
            if live.isTutorial {
                await MainActor.run { model.finishHandoff() }
            } else {
                await dropIn(handoff: true)
                await MainActor.run { model.finishHandoff() }
            }
            return
        }
        await MainActor.run {
            act = .chemistry
            liquid = 1
            tankY = 0
            lidLift = 0
            lidAngle = 360
            filmIn = 1
            cassetteFade = 0
        }
        await soak(minimum: 6)
        await pullNegative()
        await pullStrip()
    }

    private func dropIn(handoff: Bool = false) async {
        await MainActor.run {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { tankY = 0 }
        }
        try? await Task.sleep(for: .milliseconds(380))
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.55)) { cassetteY = -96 }
        }
        try? await Task.sleep(for: .milliseconds(560))
        Haptics.shared.thud()
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.6)) {
                filmIn = 1
                cassetteFade = 0
                cassetteY = -70
            }
        }
        try? await Task.sleep(for: .milliseconds(280))
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.32)) { lidLift = 0 }
        }
        try? await Task.sleep(for: .milliseconds(340))
        for step in 1...4 {
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.26)) { lidAngle = Double(step) * 90 }
            }
            try? await Task.sleep(for: .milliseconds(260))
            Haptics.shared.detent()
            Soundboard.shared.play("tick")
        }
        Haptics.shared.latch()
        try? await Task.sleep(for: .milliseconds(320))
        if handoff { return }
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.45)) { act = .chemistry }
        }
    }

    private func soak(minimum: Double) async {
        Soundboard.shared.play("water")
        Haptics.shared.soakStart()
        await MainActor.run {
            withAnimation(.easeInOut(duration: 1.2)) { liquid = 1 }
        }
        let start = Date()
        var lastBubble = start
        let deadline = start.addingTimeInterval(max(minimum, 8) + 45)
        while Date() < deadline {
            if Task.isCancelled {
                Soundboard.shared.stop("water")
                Haptics.shared.soakStop()
                return
            }
            let progressed = model.developProgress >= 1 && !model.pipelineRunning
            let elapsed = Date().timeIntervalSince(start)
            if progressed && elapsed >= minimum { break }
            let t = min(1, elapsed / minimum)
            await MainActor.run { chemPhase = CGFloat(t) }
            if Date().timeIntervalSince(lastBubble) >= 1.2 {
                Haptics.shared.soakBubble()
                lastBubble = Date()
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        await MainActor.run { chemPhase = 1 }
        Soundboard.shared.stop("water")
        Haptics.shared.soakStop()
    }

    private func pullNegative() async {
        await MainActor.run {
            act = .negative
            stripRise = 80
            negativeShown = 0
            negativeDensity = 0.12
        }
        try? await Task.sleep(for: .milliseconds(40))
        await MainActor.run {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                stripRise = 0
                tankScale = 0.42
                tankY = 48
            }
        }
        try? await Task.sleep(for: .milliseconds(360))
        let show = min(6, pairs.count)
        let warm = live
        for pair in pairs.prefix(show) {
            for frame in pair {
                _ = await model.loadNegative(roll: warm, frame: frame)
            }
        }
        for i in 0..<show {
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: Haptics.reduceMotion ? 0.04 : 0.18)) {
                    negativeShown = i + 1
                }
            }
            if i == 0 {
                Haptics.shared.swell()
            } else {
                Haptics.shared.pair()
            }
            try? await Task.sleep(for: .milliseconds(Haptics.reduceMotion ? 80 : 220))
        }
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.35)) {
                negativeShown = pairs.count
            }
            withAnimation(.easeInOut(duration: 2)) {
                negativeDensity = 1
            }
        }
        try? await Task.sleep(for: .milliseconds(2000))
    }

    private func pullStrip() async {
        await MainActor.run {
            act = .strip
        }
        try? await Task.sleep(for: .milliseconds(180))
        for i in 0..<autoReveal {
            if Task.isCancelled { return }
            await revealPair(i)
        }
    }

    private func revealPair(_ i: Int) async {
        let revealDur = Haptics.reduceMotion ? 0.04 : 0.18
        let flipDur = Haptics.reduceMotion ? 0.06 : 0.22
        await MainActor.run {
            withAnimation(.easeOut(duration: revealDur)) {
                revealedPairs = i + 1
                negativeShown = max(negativeShown, i + 1)
            }
        }
        try? await Task.sleep(for: .milliseconds(Haptics.reduceMotion ? 40 : 80))
        await MainActor.run {
            withAnimation(.easeInOut(duration: flipDur)) {
                flippedPairs = i + 1
            }
        }
        if i == 0 {
            Soundboard.shared.play("reveal")
            Haptics.shared.swell()
            await MainActor.run { flash = 0.22 }
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.55)) { flash = 0 }
            }
        } else {
            Haptics.shared.pair()
        }
        try? await Task.sleep(for: .milliseconds(Haptics.reduceMotion ? 40 : 160))
    }
}

private struct ChromeTank: View {
    var cutaway: Bool
    var liquid: CGFloat
    var coil: CGFloat
    var leader: Color
    var fluid: Color

    private let w: CGFloat = 148
    private let h: CGFloat = 196

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.34), Color(white: 0.14), Color(white: 0.22)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w, height: h)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    LinearGradient(colors: [Color(white: 0.72), Color(white: 0.28)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.4
                )
                .frame(width: w, height: h)
            LinearGradient(
                colors: [Color.white.opacity(0.22), Color.clear, Color.white.opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 18, height: h - 28)
            .offset(x: -52)
            .allowsHitTesting(false)
            if cutaway {
                interior
            }
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.55), Color(white: 0.22)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w, height: 22)
                .overlay(Ellipse().stroke(Color.white.opacity(0.28), lineWidth: 0.7))
                .offset(y: -h / 2 + 8)
            Ellipse()
                .fill(Color(white: 0.06))
                .frame(width: 118, height: 14)
                .overlay(Ellipse().stroke(Color(white: 0.32), lineWidth: 0.6))
                .offset(y: -h / 2 + 10)
        }
        .frame(width: w, height: h)
        .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
        .animation(.easeInOut(duration: 0.8), value: fluid)
        .animation(.easeInOut(duration: 0.45), value: cutaway)
    }

    private var interior: some View {
        let innerW: CGFloat = 124
        let innerH: CGFloat = 158
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(red: 0.04, green: 0.035, blue: 0.03))
                .frame(width: innerW, height: innerH)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [fluid.opacity(0.92), fluid.opacity(0.48)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: innerW - 6, height: max(4, (innerH - 12) * liquid))
                if liquid > 0.08 {
                    ChemBubbles(fluid: fluid)
                        .frame(width: innerW - 12, height: max(8, (innerH - 18) * liquid))
                        .clipped()
                }
            }
            .padding(.bottom, 10)
            FilmCoil(leader: leader, density: coil)
                .frame(width: 90, height: 90)
                .opacity(0.28 + 0.72 * coil)
                .padding(.bottom, 36)
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .offset(y: 6)
    }
}

private struct ChromeLid: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 128, height: 128)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.34), Color(white: 0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 118, height: 118)
            Circle()
                .stroke(
                    LinearGradient(colors: [Color(white: 0.72), Color(white: 0.28)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.6
                )
                .frame(width: 118, height: 118)
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: 4, height: 11)
                    .offset(y: -46)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.88), Color(white: 0.42)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 28)
            Circle()
                .fill(Color(white: 0.78))
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.6))
                .frame(width: 10, height: 10)
                .offset(y: -16)
        }
        .frame(width: 128, height: 128)
    }
}

private struct FilmCoil: View {
    var leader: Color
    var density: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) * 0.46
            for i in 0..<5 {
                let t = CGFloat(i) / 4
                let r = maxR * (0.28 + 0.72 * t)
                var ring = Path()
                ring.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                ctx.stroke(ring, with: .color(leader.opacity(0.32 + 0.55 * density)), lineWidth: 4.2 - t * 1.5)
            }
            let holeR = maxR * 0.9
            for i in 0..<16 {
                let a = Double(i) / 16 * .pi * 2
                let p = CGPoint(x: c.x + holeR * CGFloat(cos(a)), y: c.y + holeR * CGFloat(sin(a)))
                let hole = Path(roundedRect: CGRect(x: p.x - 2.1, y: p.y - 1.3, width: 4.2, height: 2.6), cornerRadius: 0.5)
                ctx.fill(hole, with: .color(.black.opacity(0.55)))
            }
            var core = Path()
            core.addEllipse(in: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14))
            ctx.fill(core, with: .color(Color(white: 0.12)))
            ctx.stroke(core, with: .color(Color(white: 0.35)), lineWidth: 0.7)
        }
    }
}

private struct ChemBubbles: View {
    var fluid: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: false)) { timeline in
            Canvas { ctx, size in
                var rng = SeededRandom(0xB0BB1E)
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<14 {
                    let x = rng.unit() * size.width
                    let speed = 18.0 + rng.unit() * 28
                    let sizeJ = 1.6 + rng.unit() * 2.8
                    let phase = rng.unit() * 8
                    let y = size.height - CGFloat((t * speed + phase * 12).truncatingRemainder(dividingBy: Double(size.height + 16)))
                    let wobble = sin(t * 2.2 + Double(i)) * 3.2
                    let rect = CGRect(x: x + wobble - sizeJ, y: y, width: sizeJ * 2, height: sizeJ * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.18)))
                    ctx.stroke(Path(ellipseIn: rect), with: .color(fluid.opacity(0.35)), lineWidth: 0.4)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
