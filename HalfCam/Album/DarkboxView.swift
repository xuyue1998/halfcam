import SwiftUI
import UIKit

struct DarkboxView: View {
    @Environment(AppModel.self) private var model
    @State private var hatchY: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.07, green: 0.06, blue: 0.055).ignoresSafeArea()
            VStack(spacing: 0) {
                HatchBar(title: L("暗盒"), close: dismissIfAllowed, closable: !lockDarkbox)
                .contentShape(Rectangle())
                .gesture(hatchDrag)

                if model.darkboxRolls.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Text(L("暗盒是空的"))
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.45))
                        Button {
                            withAnimation(.easeOut(duration: 0.28)) {
                                model.showDarkbox = false
                            }
                            if model.currentRoll == nil, !model.tutorialInProgress {
                                model.pendingLoadRoll = true
                            }
                            Haptics.shared.tick()
                        } label: {
                            ChromePlate(title: L("去装一卷"))
                                .frame(width: 160)
                        }
                        .buttonStyle(.plain)
                        .opacity(model.tutorialInProgress ? 0.4 : 1)
                        .allowsHitTesting(!model.tutorialInProgress)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(model.darkboxRolls) { roll in
                                cassette(roll)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .offset(y: hatchY)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if !model.handoffToast.isEmpty {
                ChromeToast(text: model.handoffToast)
                    .padding(.bottom, 28)
                    .transition(.opacity)
            }
        }
        .onChange(of: model.handoffToast) { _, text in
            guard !text.isEmpty else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.6))
                if model.handoffToast == text { model.handoffToast = "" }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private var lockDarkbox: Bool {
        model.tutorialLocked && model.currentRoll == nil
    }

    private var hatchDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !lockDarkbox else { return }
                hatchY = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 80 || value.predictedEndTranslation.height > 140 {
                    dismissIfAllowed()
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        hatchY = 0
                    }
                }
            }
    }

    private func dismissIfAllowed() {
        if lockDarkbox {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                hatchY = 0
            }
            return
        }
        dismissHatch()
    }

    private func dismissHatch() {
        let h = UIScreen.main.bounds.height
        withAnimation(.easeOut(duration: 0.22)) {
            hatchY = h
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                model.showDarkbox = false
            }
        }
    }

    private func cassette(_ roll: Roll) -> some View {
        let film = FilmCatalog.recipe(id: roll.filmId)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                 FilmCassetteBadge(film: film)
                VStack(alignment: .leading, spacing: 4) {
                    Text(film.name)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.white)
                    waitingStatus(roll)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(white: 0.5))
                    Text("\(roll.shotCount)/\(roll.capacity)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(white: 0.7))
                }
                Spacer()
            }
            sprocketProgress(roll, film: film)
            action(roll)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.11, blue: 0.09),
                            Color(red: 0.07, green: 0.06, blue: 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .leading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(film.packStyle.body).frame(width: 4)
                        Rectangle().fill(film.packStyle.band).frame(width: 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color(white: 0.38), Color(white: 0.16)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                )
        )
    }

    private func sprocketProgress(_ roll: Roll, film: FilmRecipe) -> some View {
        GeometryReader { geo in
            let count = max(1, roll.capacity)
            let filled = min(roll.shotCount, count)
            let gap = min(5, max(2, geo.size.width / CGFloat(count) * 0.28))
            let hole = min(7, max(4.5, (geo.size.width - gap * CGFloat(count - 1)) / CGFloat(count)))
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < filled ? film.pack : Color(white: 0.18))
                        .frame(width: hole, height: 7)
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
        }
        .frame(height: 7)
    }

    @ViewBuilder
    private func action(_ roll: Roll) -> some View {
        if roll.state == .canDevelop {
            Button {
                Haptics.shared.latch()
                model.submitDevelop(roll.id)
            } label: {
                ChromePlate(title: L("送去显影"), prominent: true)
            }
            .buttonStyle(.plain)
            .modifier(PulseScaleModifier(amount: 1.04, active: model.isOnboarding && roll.isTutorial, repeats: true))
        } else if roll.state == .waiting {
            if isHandingOff(roll) {
                ChromePlate(title: L("送进暗房"), prominent: false)
            } else {
                waitAction(roll)
            }
        } else if roll.state == .shooting, model.currentRollId == roll.id {
            Text(roll.remaining == 0 ? L("请倒片") : L("还剩 \(roll.remaining) 格"))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(white: 0.45))
        } else if roll.state == .needsRewind {
            Button {
                withAnimation(.easeOut(duration: 0.28)) {
                    model.showDarkbox = false
                }
                Haptics.shared.tick()
            } label: {
                ChromePlate(title: L("回到相机，按住倒片"), prominent: false)
            }
            .buttonStyle(.plain)
        } else if roll.state == .developing {
            Button {
                Haptics.shared.latch()
                model.resumeRitual(roll.id)
            } label: {
                let film = FilmCatalog.recipe(id: roll.filmId)
                ChromePlate(
                    title: developStageTitle(
                        process: film.process,
                        phase: CGFloat(model.developProgress),
                        progress: model.developProgress
                    ),
                    prominent: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func waitAction(_ roll: Roll) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, (roll.developReadyAt ?? context.date).timeIntervalSince(context.date))
            if left <= 0 {
                Button {
                    Haptics.shared.latch()
                    model.collectDevelop(roll.id)
                } label: {
                    ChromePlate(title: L("取出"), prominent: true)
                }
                .buttonStyle(.plain)
            } else {
                ChromePlate(title: waitClock(left), prominent: false)
            }
        }
        .modifier(PulseScaleModifier(
            amount: 1.04,
            active: model.isOnboarding && roll.isTutorial && roll.isWaitReady,
            repeats: true
        ))
        .task(id: roll.developReadyAt) {
            guard let ready = roll.developReadyAt else { return }
            let delay = ready.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            model.refreshLiveActivities()
        }
    }

    @ViewBuilder
    private func waitingStatus(_ roll: Roll) -> some View {
        if isHandingOff(roll) {
            Text(L("送进暗房"))
        } else if roll.state == .waiting {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = max(0, (roll.developReadyAt ?? context.date).timeIntervalSince(context.date))
                Text(left <= 0 ? L("可取件") : L("显影中"))
            }
        } else {
            Text(statusText(roll))
        }
    }

    private func isHandingOff(_ roll: Roll) -> Bool {
        model.showDarkroom && model.ritualRollId == roll.id
    }

    private func statusText(_ roll: Roll) -> String {
        switch roll.state {
        case .shooting: L("拍摄中")
        case .needsRewind: L("待倒片")
        case .canDevelop: L("待显影")
        case .waiting: L("显影中")
        case .developing: L("显影中")
        case .ready: L("已洗好")
        }
    }
}
