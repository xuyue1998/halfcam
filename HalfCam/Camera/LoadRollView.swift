import SwiftUI

struct LoadRollView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selected = "kodak_portra_400"
    @State private var grain: GrainLevel = .medium
    @State private var dateStamp = false
    @State private var paperId = "kodak_portra_endura"
    @State private var cameraFilter = ""
    @State private var capacity = 12
    @State private var group: FilmGroup = .color
    @State private var inserting = false
    @State private var cassetteY: CGFloat = -80
    @State private var sampleIndex: Int? = nil

    private var film: FilmRecipe { FilmCatalog.recipe(id: selected) }
    private var groupFilms: [FilmRecipe] { FilmCatalog.films(in: group) }
    private var tutorial: Bool { model.isOnboarding }

    var body: some View {
        ZStack {
            cavity
            if inserting {
                insertOverlay
            } else if tutorial {
                tutorialBody
            } else {
                fullBody
            }
        }
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .onAppear {
            model.presentingLoadRoll = true
            Soundboard.shared.play("back")
            syncFilmDefaults()
            if !tutorial {
                capacity = model.defaultCapacity
            }
        }
        .onDisappear {
            model.presentingLoadRoll = false
        }
        .onChange(of: model.tier) { _, _ in
            model.syncSkipGrant()
            if !tutorial, !model.canUseCapacity(capacity) {
                capacity = model.defaultCapacity
            }
        }
        .onChange(of: selected) { _, _ in
            sampleIndex = nil
            syncFilmDefaults()
        }
        .onChange(of: group) { _, newGroup in
            pickGroup(newGroup)
        }
        .overlay {
            if model.showPaywall {
                PaywallView()
                    .environment(model)
                    .environment(\.locale, model.language.locale)
            }
            if sampleIndex != nil {
                FilmSampleLightbox(urls: FilmSamples.urls(for: selected), index: $sampleIndex)
            }
        }
    }

    private var cavity: some View {
        ZStack {
            HalfColor.cavity
            RadialGradient(
                colors: [HalfColor.safelight.opacity(0.55), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var tutorialBody: some View {
        VStack(spacing: 22) {
            Spacer()
            FilmPackView(film: film, selected: true)
            Text(L("新手教程"))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color(white: 0.5))
            FilmSampleStrip(filmId: selected) { sampleIndex = $0 }
                .padding(.horizontal, 8)
            Spacer()
            Button {
                beginInsert()
            } label: {
                HatchPlate(title: L("装入体验卷 · 2 格"), prominent: true)
            }
            .buttonStyle(.plain)
            .disabled(inserting)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            latch
            QuotaPlate()
                .padding(.horizontal, 20)
            groupBar
                .padding(.horizontal, 20)
            packRow
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    personality
                        .padding(.horizontal, 20)
                    FilmSampleStrip(filmId: selected) { sampleIndex = $0 }
                        .padding(.horizontal, 20)
                    VStack(alignment: .leading, spacing: 14) {
                        capacityRow
                        temperRow(L("颗粒")) {
                            MetalSelector(
                                labels: GrainLevel.allCases.map(\.title),
                                selected: GrainLevel.allCases.firstIndex(of: grain) ?? 2
                            ) { i in
                                grain = GrainLevel.allCases[i]
                            }
                        }
                        if film.papers.count > 1 {
                            paperRow
                        }
                        if film.process == .bw {
                            temperRow(L("滤镜")) {
                                MetalSelector(
                                    labels: CameraFilter.allCases.map(\.title),
                                    selected: CameraFilter.allCases.firstIndex(where: { $0.rawValue == cameraFilter }) ?? 0
                                ) { i in
                                    cameraFilter = CameraFilter.allCases[i].rawValue
                                }
                            }
                        }
                        temperRow(L("日期印")) {
                            MetalSelector(
                                labels: [L("关"), L("开")],
                                selected: dateStamp ? 1 : 0
                            ) { i in
                                dateStamp = i == 1
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            Button {
                tapInsert()
            } label: {
                HatchPlate(title: insertTitle, prominent: true)
            }
            .buttonStyle(.plain)
            .disabled(inserting)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .padding(.top, 10)
    }

    private var latch: some View {
        HStack {
            CloseLatch { dismiss() }
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    private var groupBar: some View {
        MetalSelector(
            labels: FilmGroup.allCases.map(\.title),
            selected: FilmGroup.allCases.firstIndex(of: group) ?? 0
        ) { i in
            group = FilmGroup.allCases[i]
        }
    }

    private var packRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(groupFilms) { item in
                    FilmPackView(film: item, selected: selected == item.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                selected = item.id
                            }
                            Haptics.shared.chrome()
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }

    private var personality: some View {
        HStack(spacing: 10) {
            FilmPackChip(film: film, width: 10, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(film.name)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.9))
                Text(LKey(film.subtitle))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.55))
            }
            Spacer()
            Text("ISO \(film.iso)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.5))
        }
    }

    private var capacityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("格数"))
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.78))
            HStack(spacing: 6) {
                ForEach(AppConst.capacities, id: \.self) { n in
                    let on = capacity == n
                    let allowed = model.canUseCapacity(n)
                    Button {
                        if allowed {
                            capacity = n
                        } else {
                            model.showPaywall = true
                        }
                        Haptics.shared.chrome()
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(n)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            Text(capacityLabel(n))
                                .font(.system(size: 8, design: .monospaced))
                        }
                        .foregroundStyle(on ? Color.white : Color(white: allowed ? 0.5 : 0.28))
                        .opacity(allowed ? 1 : 0.45)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(on ? 0.16 : 0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(on ? 0.42 : 0.14), lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var paperRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Text(L("相纸"))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color(white: 0.78))
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(film.papers, id: \.self) { id in
                            let on = paperId == id
                            Button {
                                paperId = id
                                Haptics.shared.chrome()
                            } label: {
                                Text(PaperCatalog.name(id))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(on ? Color.white : Color(white: 0.5))
                                    .padding(.horizontal, 10)
                                    .frame(height: 26)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(on ? 0.18 : 0.06))
                                            .overlay(Capsule().stroke(Color.white.opacity(on ? 0.42 : 0.14), lineWidth: 0.8))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            let blurb = PaperCatalog.blurb(paperId)
            if !blurb.isEmpty {
                Text(blurb)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(white: 0.42))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func temperRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color(white: 0.78))
            Spacer()
            content()
        }
    }

    private var insertOverlay: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 120, height: 86)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                Image("FilmCassette")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 56)
                    .offset(y: cassetteY)
            }
            Text(L("装入机身"))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.7))
            Spacer()
        }
    }

    private func capacityLabel(_ n: Int) -> String {
        switch n {
        case 12: L("短卷")
        case 24: L("中卷")
        case 36: L("长卷")
        case 54: L("加长")
        default: L("全卷")
        }
    }

    private func pickGroup(_ newGroup: FilmGroup) {
        let films = FilmCatalog.films(in: newGroup)
        guard !films.contains(where: { $0.id == selected }), let first = films.first else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            selected = first.id
        }
    }

    private func syncFilmDefaults() {
        paperId = film.defaultPaperId
        if film.process != .bw {
            cameraFilter = ""
        }
        grain = film.grain
        if film.group != group {
            group = film.group
        }
    }

    private var insertTitle: String {
        model.canLoadRoll ? L("装入 · \(capacity) 格") : L("本月卷已用尽")
    }

    private func tapInsert() {
        if !model.canLoadRoll || !model.canUseCapacity(capacity) {
            model.showPaywall = true
            Haptics.shared.chrome()
            return
        }
        beginInsert()
    }

    private func beginInsert() {
        inserting = true
        Haptics.shared.chrome()
        cassetteY = -80
        let drop = Haptics.reduceMotion ? 0.2 : 0.55
        withAnimation(.easeInOut(duration: drop)) {
            cassetteY = 8
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(drop * 1000)))
            Haptics.shared.thud()
            try? await Task.sleep(for: .milliseconds(80))
            model.loadRoll(
                film: film,
                grain: grain,
                leak: .off,
                diffusion: .off,
                dateStamp: dateStamp,
                paperId: paperId,
                cameraFilter: cameraFilter,
                capacity: tutorial ? AppConst.tutorialCapacity : capacity,
                isTutorial: tutorial
            )
            dismiss()
        }
    }
}
