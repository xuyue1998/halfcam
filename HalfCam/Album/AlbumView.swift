import SwiftUI
import UIKit

func filmPairs(_ frames: [Frame]) -> [[Frame]] {
    stride(from: 0, to: frames.count, by: 2).map { i in
        Array(frames[i..<min(i + 2, frames.count)])
    }
}

struct AlbumView: View {
    @Environment(AppModel.self) private var model
    @State private var toast = ""
    @State private var pendingDelete: Roll?
    @State private var exporting = false
    @State private var hatchY: CGFloat = 0
    @State private var openedRollId: UUID?
    @State private var viewingPair: PairViewing?
    @State private var showKeepHint = false

    struct PairViewing: Identifiable {
        var id: Int { index }
        var roll: Roll
        var index: Int
    }

    private var openedRoll: Roll? {
        guard let openedRollId else { return nil }
        return model.albumRolls.first { $0.id == openedRollId }
    }

    private var capTitle: String {
        if let roll = openedRoll {
            return FilmCatalog.recipe(id: roll.filmId).name
        }
        return L("相册")
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.07, green: 0.06, blue: 0.055).ignoresSafeArea()
            VStack(spacing: 0) {
                HatchBar(title: capTitle, close: closeCap) {
                    HStack(spacing: 8) {
                        if let roll = openedRoll, model.hasUnexportedPrints(roll) {
                            dumpRollButton(roll)
                        }
                        gearButton
                    }
                }
                .contentShape(Rectangle())
                .gesture(hatchDrag)

                ZStack {
                    if let roll = openedRoll {
                        rollStrip(roll)
                    } else if model.albumRolls.isEmpty {
                        emptyState
                    } else {
                        rollList
                    }
                    toastLayer
                }
            }

            if let item = viewingPair {
                let live = model.albumRolls.first(where: { $0.id == item.roll.id }) ?? item.roll
                PairViewer(
                    roll: live,
                    startIndex: item.index,
                    onClose: { viewingPair = nil }
                ) { pair in
                    model.markExportHint()
                    Task { await exportFrames(live, pair) }
                }
                .onAppear { model.markExportHint() }
            }

            if showKeepHint, pendingDelete == nil, viewingPair == nil {
                ChromeConfirm(
                    title: L("底片只在这台机里"),
                    message: L("删除 App 会把没倒走的照片一起清掉。洗好的，可以先倒进系统相册。"),
                    confirmTitle: L("倒出全部未导出"),
                    confirm: {
                        showKeepHint = false
                        model.markKeepHint()
                        Task { await dumpAllFromHint() }
                    },
                    cancel: {
                        showKeepHint = false
                        model.markKeepHint()
                    }
                )
            }

            if let roll = pendingDelete {
                ChromeConfirm(
                    title: L("抽出这卷？"),
                    message: L("洗好的 \(roll.shotCount) 格会从本机清掉。系统相册里倒走过的还在。"),
                    confirmTitle: L("抽出"),
                    confirm: {
                        if openedRollId == roll.id { openedRollId = nil }
                        viewingPair = nil
                        withAnimation(.easeInOut(duration: 0.22)) {
                            model.deleteAlbumRoll(roll.id)
                        }
                        toast = L("已抽出")
                        clearToast()
                        pendingDelete = nil
                    },
                    cancel: { pendingDelete = nil }
                )
            }
        }
        .offset(y: hatchY)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: openedRollId)
        .onChange(of: openedGone) { _, gone in
            if gone {
                openedRollId = nil
                viewingPair = nil
            }
        }
        .onAppear { maybeShowKeepHint() }
    }

    private var openedGone: Bool {
        guard let openedRollId else { return false }
        return model.rolls.first(where: { $0.id == openedRollId })?.state != .ready
    }

    private var gearButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.28)) {
                model.showSettings = true
            }
            Haptics.shared.chrome()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.34), Color(white: 0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 28, height: 28)
                Circle()
                    .stroke(
                        LinearGradient(colors: [Color(white: 0.72), Color(white: 0.28)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.2
                    )
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(Color(white: 0.72))
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text(L("洗好的胶卷会在这里"))
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.45))
            Button {
                withAnimation(.easeOut(duration: 0.28)) {
                    model.showAlbum = false
                }
                if model.currentRoll == nil { model.pendingLoadRoll = true }
                Haptics.shared.tick()
            } label: {
                ChromePlate(title: model.currentRoll == nil ? L("去装一卷") : L("去拍一卷"))
                    .frame(width: 160)
            }
            .buttonStyle(.plain)
        }
    }

    private var rollList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.albumRolls) { roll in
                    AlbumRollCard(roll: roll, pendingDelete: $pendingDelete) {
                        openedRollId = roll.id
                        Haptics.shared.tick()
                    } content: {
                        collapsedCard(roll)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var toastLayer: some View {
        Group {
            if !toast.isEmpty {
                VStack {
                    Spacer()
                    ChromeToast(text: toast)
                        .padding(.bottom, 24)
                }
                .allowsHitTesting(false)
            } else if !model.hasSeenExportHint, viewingPair != nil {
                VStack {
                    Spacer()
                    ChromeToast(text: L("点一格倒出单张"))
                        .padding(.bottom, 24)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func closeCap() {
        if viewingPair != nil {
            viewingPair = nil
        } else if openedRollId != nil {
            openedRollId = nil
        } else {
            withAnimation(.easeOut(duration: 0.28)) {
                model.showAlbum = false
            }
        }
    }

    private var hatchDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard openedRollId == nil, viewingPair == nil else { return }
                hatchY = max(0, value.translation.height)
            }
            .onEnded { value in
                guard openedRollId == nil, viewingPair == nil else {
                    hatchY = 0
                    return
                }
                if value.translation.height > 80 || value.predictedEndTranslation.height > 140 {
                    dismissHatch()
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        hatchY = 0
                    }
                }
            }
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
                model.showAlbum = false
            }
        }
    }

    private func collapsedCard(_ roll: Roll) -> some View {
        let film = FilmCatalog.recipe(id: roll.filmId)
        let pairs = filmPairs(roll.frames)
        let extra = max(0, pairs.count - 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                FilmPackChip(film: film, width: 10, height: 14)
                Text(film.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(white: 0.88))
                Text(L("\(roll.shotCount) 格"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(white: 0.45))
                Spacer()
                if model.hasUnexportedPrints(roll) {
                    Text(L("未倒出"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(white: 0.55))
                }
                if extra > 0 {
                    Text(L("\(extra) 对在卷里"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(white: 0.5))
                }
            }
            if let first = pairs.first {
                previewStrip(roll, first)
            }
        }
        .padding(14)
        .background(cassetteShell(film))
        .padding(.horizontal, 16)
    }

    private func rollStrip(_ roll: Roll) -> some View {
        let pairs = filmPairs(roll.frames)
        return ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { i, pair in
                    pairCell(roll, pair, index: i)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func pairCell(_ roll: Roll, _ pair: [Frame], index: Int) -> some View {
        Button {
            viewingPair = PairViewing(roll: roll, index: index)
            Haptics.shared.tick()
        } label: {
            previewStrip(roll, pair)
        }
        .buttonStyle(.plain)
    }

    private func previewStrip(_ roll: Roll, _ pair: [Frame]) -> some View {
        let strip = FilmSprocketFrame(rebates: pair.map { filmRebate($0.index) }) {
            HStack(spacing: 2) {
                ForEach(pair) { frame in
                    thumb(roll, frame)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .clipped()
                }
            }
        }
        return Group {
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

    private func cassetteShell(_ film: FilmRecipe) -> some View {
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
    }

    private func thumb(_ roll: Roll, _ frame: Frame) -> some View {
        FrameStill(roll: roll, frame: frame, kind: .preview)
    }

    private func liveFrames(_ roll: Roll, _ frames: [Frame]) -> [Frame] {
        frames.compactMap { model.liveFrame(rollId: roll.id, frameId: $0.id) ?? $0 }
    }

    private func dumpRollButton(_ roll: Roll) -> some View {
        Button {
            Task { await dumpRoll(roll) }
        } label: {
            ChromePlate(
                title: exporting || model.exportBusy ? L("正在倒出") : L("倒出这卷"),
                prominent: false
            )
            .frame(width: 96)
        }
        .buttonStyle(.plain)
        .disabled(exporting || model.exportBusy)
    }

    private func dumpRoll(_ roll: Roll) async {
        guard !exporting else { return }
        exporting = true
        defer { exporting = false }
        let outcome = await model.exportPrints(rollId: roll.id)
        if case .saved = outcome {
            Haptics.shared.latch()
        }
        toast = PhotoExport.toast(outcome)
        clearToast()
    }

    private func exportFrames(_ roll: Roll, _ frames: [Frame]) async {
        let live = liveFrames(roll, frames)
        guard !live.isEmpty else { return }
        guard !exporting else { return }
        exporting = true
        defer { exporting = false }
        let urls: [URL] = live.compactMap { frame in
            model.exportJPEGURL(roll: roll, frame: frame)
        }
        guard !urls.isEmpty else {
            toast = L("没有成片")
            clearToast()
            return
        }
        let ids = live.map(\.id)
        let payload = await Task.detached(priority: .userInitiated) {
            Self.exportJPEG(urls: urls)
        }.value
        guard let payload else {
            toast = L("没有成片")
            clearToast()
            return
        }
        let outcome = await model.exportJPEGPayload(payload, rollId: roll.id, frameIds: ids)
        if case .saved = outcome {
            Haptics.shared.latch()
        }
        toast = PhotoExport.toast(outcome)
        clearToast()
    }

    nonisolated private static func exportJPEG(urls: [URL]) -> Data? {
        if urls.count == 1, let data = try? Data(contentsOf: urls[0]), !data.isEmpty {
            return data
        }
        let images = urls.compactMap { ImageStore.decodeExport($0, maxSide: 1600) }
        guard !images.isEmpty else { return nil }
        let h: CGFloat = 1600
        let w: CGFloat = h * 3 / 4
        let gap: CGFloat = images.count > 1 ? 10 : 0
        let canvas = CGSize(width: w * CGFloat(images.count) + gap * CGFloat(max(0, images.count - 1)), height: h)
        let renderer = UIGraphicsImageRenderer(size: canvas)
        let composed = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))
            for (i, img) in images.enumerated() {
                let rect = CGRect(x: CGFloat(i) * (w + gap), y: 0, width: w, height: h)
                img.draw(in: rect)
            }
        }
        guard let jpeg = composed.jpegData(compressionQuality: 0.92) else { return nil }
        guard let source = try? Data(contentsOf: urls[0]) else { return jpeg }
        return FilmRenderer.stampExport(jpeg, like: source)
    }

    private func clearToast() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { toast = "" }
    }

    private func maybeShowKeepHint() {
        guard !model.hasSeenKeepHint, model.unexportedRollCount > 0 else { return }
        showKeepHint = true
    }

    private func dumpAllFromHint() async {
        guard !exporting else { return }
        exporting = true
        defer { exporting = false }
        let outcome = await model.exportAllUnexportedPrints()
        if case .saved = outcome {
            Haptics.shared.latch()
        }
        toast = PhotoExport.toast(outcome)
        clearToast()
    }
}

private struct AlbumRollCard<Content: View>: View {
    var roll: Roll
    @Binding var pendingDelete: Roll?
    var onOpen: () -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    @State private var axis: Axis?
    @State private var suppressTap = false

    private let reveal: CGFloat = 88

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                pendingDelete = roll
            } label: {
                VStack(spacing: 6) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.88), Color(white: 0.42)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 18, height: 6)
                        .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
                    Text(L("抽出"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.82))
                }
                .frame(width: reveal)
                .frame(maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(white: 0.22), Color(white: 0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .buttonStyle(.plain)
            .opacity(offset < -8 ? 1 : 0)
            .zIndex(offset < -8 ? 1 : 0)

            content
                .contentShape(Rectangle())
                .offset(x: offset)
                .onTapGesture {
                    guard !suppressTap, axis != .horizontal, abs(offset) < 2 else { return }
                    onOpen()
                }
                .highPriorityGesture(drag)
        }
        .clipped()
        .onChange(of: pendingDelete?.id) { _, id in
            if id != roll.id {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    offset = 0
                }
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if axis == nil {
                    startOffset = offset
                    if abs(dx) > abs(dy) * 1.4 { axis = .horizontal }
                    else if abs(dy) > abs(dx) { axis = .vertical }
                }
                guard axis == .horizontal else { return }
                suppressTap = true
                offset = min(0, max(-reveal, startOffset + dx))
            }
            .onEnded { value in
                let wasHorizontal = axis == .horizontal
                defer { axis = nil }
                guard wasHorizontal else {
                    suppressTap = false
                    return
                }
                let predicted = startOffset + value.predictedEndTranslation.width
                let open = offset < -reveal * 0.45 || predicted < -reveal * 0.55
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    offset = open ? -reveal : 0
                }
                if !open {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        suppressTap = false
                    }
                }
            }
    }
}

private struct PairViewer: View {
    @Environment(AppModel.self) private var model
    var roll: Roll
    var startIndex: Int
    var onClose: () -> Void
    var export: ([Frame]) -> Void
    @State private var page: Int
    @State private var selectedId: UUID?

    init(roll: Roll, startIndex: Int, onClose: @escaping () -> Void, export: @escaping ([Frame]) -> Void) {
        self.roll = roll
        self.startIndex = startIndex
        self.onClose = onClose
        self.export = export
        let count = max(1, filmPairs(roll.frames).count)
        _page = State(initialValue: min(max(0, startIndex), count - 1))
    }

    private var live: Roll {
        model.albumRolls.first(where: { $0.id == roll.id }) ?? roll
    }

    private var pairs: [[Frame]] { filmPairs(live.frames) }

    private var current: [Frame] {
        guard pairs.indices.contains(page) else { return pairs.first ?? [] }
        return pairs[page]
    }

    private var selectedFrame: Frame? {
        current.first { $0.id == selectedId }
    }

    private var capTitle: String {
        let film = FilmCatalog.recipe(id: live.filmId)
        return "\(film.name)  \(page + 1)/\(max(1, pairs.count))"
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.055).ignoresSafeArea()
            VStack(spacing: 0) {
                HatchBar(title: capTitle, close: onClose) {
                    Button {
                        if let frame = selectedFrame {
                            export([frame])
                        } else {
                            export(current)
                        }
                    } label: {
                        ChromePlate(title: selectedFrame == nil ? L("倒出这对") : L("倒出这格"), prominent: false)
                            .frame(width: 96)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.exportBusy)
                }
                TabView(selection: $page) {
                    ForEach(Array(pairs.enumerated()), id: \.offset) { i, pair in
                        pairPage(pair)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: page) { _, _ in
                    selectedId = nil
                }
            }
        }
        .statusBarHidden()
    }

    private func pairPage(_ pair: [Frame]) -> some View {
        VStack {
            Spacer(minLength: 0)
            let strip = FilmSprocketFrame(rebates: pair.map { filmRebate($0.index) }) {
                HStack(spacing: 2) {
                    ForEach(pair) { frame in
                        let on = selectedId == frame.id
                        FrameStill(roll: live, frame: frame, kind: .display)
                            .overlay {
                                Rectangle()
                                    .stroke(Color(white: 0.82), lineWidth: on ? 2 : 0)
                            }
                            .clipped()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedId = selectedId == frame.id ? nil : frame.id
                                Haptics.shared.tick()
                            }
                    }
                }
            }
            if pair.count == 1 {
                HStack(spacing: 0) {
                    strip
                    Color.clear.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
            } else {
                strip.padding(.horizontal, 16)
            }
            Spacer(minLength: 0)
        }
    }
}

func filmRebate(_ index: Int) -> String {
    let n = max(1, (index + 1) / 2)
    return index % 2 == 1 ? "\(n)" : "\(n)A"
}

struct FrameStill: View {
    enum Kind {
        case preview, display, negative
    }

    @Environment(AppModel.self) private var model
    var roll: Roll
    var frame: Frame
    var kind: Kind
    var empty: Color = Color(white: 0.12)
    @State private var image: UIImage?

    var body: some View {
        Color.black
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                } else {
                    empty
                }
            }
            .clipped()
            .task(id: token) {
                image = cached
                if image != nil { return }
                switch kind {
                case .preview:
                    image = await model.loadPreview(roll: roll, frame: frame)
                case .display:
                    image = await model.loadDisplay(roll: roll, frame: frame)
                case .negative:
                    image = await model.loadNegative(roll: roll, frame: frame)
                }
            }
    }

    private var token: String {
        "\(kind)-\(roll.id.uuidString)-\(frame.id.uuidString)-\(frame.thumbFileName ?? frame.posFileName ?? "")-\(frame.developed)"
    }

    private var cached: UIImage? {
        switch kind {
        case .preview: model.cachedPreview(roll: roll, frame: frame)
        case .display: model.cachedDisplay(roll: roll, frame: frame)
        case .negative: model.cachedNegative(roll: roll, frame: frame)
        }
    }
}

struct FilmSprocketFrame<Content: View>: View {
    var rebates: [String] = []
    @ViewBuilder var content: Content

    private let base = Color(red: 0.07, green: 0.055, blue: 0.04)

    var body: some View {
        content
            .clipped()
            .padding(.vertical, 30)
            .background(base)
            .overlay(alignment: .top) { edge(top: true) }
            .overlay(alignment: .bottom) { edge(top: false) }
            .clipped()
    }

    private func edge(top: Bool) -> some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            let holeW: CGFloat = 13.5
            let holeH: CGFloat = 9.4
            let pitch: CGFloat = 23
            let y = top ? (size.height - holeH) * 0.42 : (size.height - holeH) * 0.38
            let holeFill = Color(red: 0.93, green: 0.90, blue: 0.82)
            let rim = Color(red: 0.22, green: 0.18, blue: 0.12)
            var x = -holeW * 0.45
            while x < size.width {
                let rect = CGRect(x: x, y: y, width: holeW, height: holeH)
                let path = Path(roundedRect: rect, cornerRadius: 1.8)
                ctx.fill(path, with: .color(holeFill))
                ctx.stroke(path, with: .color(rim), lineWidth: 0.7)
                var inner = Path()
                inner.addEllipse(in: CGRect(x: rect.minX + 1.6, y: rect.minY + 0.6, width: rect.width - 3.2, height: 2.4))
                ctx.fill(inner, with: .color(.white.opacity(0.22)))
                x += pitch
            }
            if top, !rebates.isEmpty {
                let font = Font.system(size: 9, weight: .medium, design: .monospaced)
                for (i, code) in rebates.enumerated() {
                    let cx = size.width * (CGFloat(i) + 0.5) / CGFloat(rebates.count)
                    let resolved = ctx.resolve(
                        Text(code)
                            .font(font)
                            .foregroundColor(Color(red: 0.86, green: 0.62, blue: 0.18).opacity(0.92))
                    )
                    let ts = resolved.measure(in: CGSize(width: 80, height: 16))
                    ctx.draw(resolved, in: CGRect(x: cx - ts.width / 2, y: size.height - ts.height - 1.5, width: ts.width, height: ts.height))
                }
            }
        }
        .frame(height: 30)
        .clipped()
    }
}

struct SettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var dragY: CGFloat = 0

    var body: some View {
        let h = UIScreen.main.bounds.height
        let sheetH = h * 0.72
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45 * max(0, 1 - dragY / sheetH))
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                    Text(L("设置"))
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(white: 0.78))
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(drag)
                ScrollView(showsIndicators: false) {
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: sheetH, alignment: .top)
            .background(Color(red: 0.07, green: 0.06, blue: 0.055))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
            )
            .offset(y: max(0, dragY))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                dragY = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 80 || value.predictedEndTranslation.height > 140 {
                    dismiss()
                } else {
                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.88)) {
                        dragY = 0
                    }
                }
            }
    }

    private func dismiss() {
        Soundboard.shared.play("back")
        Haptics.shared.latch()
        let sheetH = UIScreen.main.bounds.height * 0.72
        withAnimation(.easeOut(duration: 0.32)) {
            dragY = sheetH
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                model.showSettings = false
            }
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var storageText = "—"
    @State private var dumpNote = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            group(L("手感")) {
                feelRow(L("声音"), on: model.soundOn) {
                    model.soundOn.toggle()
                    model.applyFeel()
                }
                feelRow(L("触感"), on: model.hapticOn) {
                    model.hapticOn.toggle()
                    model.applyFeel()
                }
            }
            group(L("规则")) {
                feelRow(L("严格模式"), on: model.strictMode) {
                    model.setStrictMode(!model.strictMode)
                }
                note(L("拍过就不能中途卸，拍满才能洗"))
            }
            group(L("拍摄")) {
                feelRow("ProRAW", on: model.proRAW) {
                    model.setProRAW(!model.proRAW)
                }
                note(L("打开后负片按 RAW 保存，冲洗更慢、更占空间"))
            }
            group(L("底片")) {
                infoRow(L("本机占用"), storageText)
                infoRow(L("未倒出"), unexportedLabel)
                feelRow(L("洗完自动倒出"), on: model.autoExportPrints) {
                    model.setAutoExportPrints(!model.autoExportPrints)
                }
                note(L("只倒洗好的正片。打开后，之后洗完的卷会自动倒走；已经洗好的用下面倒出。"))
                note(L("要腾地方用卸载，不要删除。卸载会留下底片。"))
                if model.unexportedRollCount > 0 {
                    Button {
                        Task { await dumpAll() }
                    } label: {
                        HStack {
                            Text(model.exportBusy ? L("正在倒出") : L("倒出全部未导出"))
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(Color(white: 0.78))
                            Spacer()
                            Text("›")
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundStyle(Color(white: 0.42))
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.exportBusy)
                }
                if !dumpNote.isEmpty {
                    note(dumpNote)
                }
            }
            group(L("语言")) {
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { item in
                        Button {
                            model.setLanguage(item)
                            Haptics.shared.chrome()
                        } label: {
                            HStack {
                                Text(item.menuTitle)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.78))
                                Spacer()
                                Capsule()
                                    .fill(Color.black.opacity(0.45))
                                    .overlay(Capsule().stroke(Color(white: 0.32), lineWidth: 0.8))
                                    .frame(width: 28, height: 18)
                                    .overlay {
                                        if model.language == item {
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(white: 0.82), Color(white: 0.42)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
                                                .padding(2)
                                        }
                                    }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            #if DEBUG
            group(L("测试")) {
                Button {
                    Haptics.shared.latch()
                    model.resetOnboardingForTest()
                } label: {
                    HStack {
                        Text(L("重做新手引导"))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color(white: 0.78))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                note(L("会卸下机身这卷，暗盒里未洗完的体验卷也清掉"))
            }
            #endif
            Button {
                Haptics.shared.chrome()
                UIApplication.shared.open(Legal.page)
            } label: {
                Text(L("法律信息"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(white: 0.32))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .preferredColorScheme(.dark)
        .onAppear { refreshStorage() }
    }

    private var unexportedLabel: String {
        let count = model.unexportedRollCount
        return count == 0 ? L("都已倒走") : L("\(count) 卷未倒出")
    }

    private func refreshStorage() {
        Task {
            storageText = await model.formattedStorage()
        }
    }

    private func dumpAll() async {
        dumpNote = ""
        let outcome = await model.exportAllUnexportedPrints()
        if case .saved = outcome {
            Haptics.shared.latch()
        }
        dumpNote = PhotoExport.toast(outcome)
        refreshStorage()
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(Color(white: 0.48))
            content()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color(white: 0.38))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color(white: 0.78))
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color(white: 0.48))
        }
        .padding(.vertical, 4)
    }

    private func feelRow(_ title: String, on: Bool, toggle: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color(white: 0.78))
            Spacer()
            MetalSelector(labels: [L("关"), L("开")], selected: on ? 1 : 0) { _ in
                toggle()
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
    }
}
