import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            CameraView()
                .ignoresSafeArea(.keyboard)
            if model.showDarkroom, let id = model.ritualRollId, let roll = model.rolls.first(where: { $0.id == id }) {
                DarkroomView(rollId: id, roll: roll)
                    .environment(model)
                    .environment(\.locale, model.language.locale)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            if model.showPaywall, !model.presentingLoadRoll {
                PaywallView()
                    .environment(model)
                    .environment(\.locale, model.language.locale)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.16), value: model.showDarkroom)
        .animation(.easeOut(duration: 0.16), value: model.showPaywall)
        .environment(\.locale, model.language.locale)
    }
}

struct HatchBar<Trailing: View>: View {
    var title: String
    var close: () -> Void
    var closable: Bool = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title)
                .font(HalfType.serif(13))
                .foregroundStyle(HalfColor.ink.opacity(0.86))
            HStack {
                if closable {
                    CloseLatch(action: close)
                }
                Spacer(minLength: 0)
                trailing
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

extension HatchBar where Trailing == EmptyView {
    init(title: String, close: @escaping () -> Void, closable: Bool = true) {
        self.init(title: title, close: close, closable: closable) { EmptyView() }
    }
}

struct SheetEdgeAttach: UIViewRepresentable {
    var cornerRadius: CGFloat

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            attach(from: uiView)
        }
    }

    private func attach(from view: UIView) {
        var responder: UIResponder? = view
        while let current = responder {
            if let controller = current as? UIViewController,
               let sheet = controller.sheetPresentationController {
                sheet.prefersEdgeAttachedInCompactHeight = true
                sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = false
                sheet.preferredCornerRadius = cornerRadius
                return
            }
            responder = current.next
        }
    }
}

struct CloseLatch: View {
    var title: String = L("合上")
    var action: () -> Void

    var body: some View {
        Button {
            Soundboard.shared.play("back")
            Haptics.shared.latch()
            action()
        } label: {
            HStack(spacing: 8) {
                Capsule()
                    .fill(HalfChrome.latchFill)
                    .frame(width: 18, height: 6)
                    .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
                Text(title)
                    .font(HalfType.plate(12))
                    .foregroundStyle(HalfColor.ink.opacity(0.86))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct QuotaPlate: View {
    @Environment(AppModel.self) private var model
    var compact: Bool = false

    private var depleted: Bool {
        guard let cap = model.monthlyLimit else { return false }
        return model.loadsThisMonth >= cap
    }

    private var low: Bool {
        guard let cap = model.monthlyLimit else { return false }
        return cap - model.loadsThisMonth <= 1
    }

    private var countText: String {
        if let cap = model.monthlyLimit {
            return String(format: "%02d / %02d", model.loadsThisMonth, cap)
        }
        return L("不限")
    }

    private var countColor: Color {
        low ? HalfColor.warn : (compact ? Color(white: 0.72) : HalfColor.ink)
    }

    var body: some View {
        if compact {
            compactChip
        } else {
            fullPlate
        }
    }

    private var paid: Bool { model.tier != .free }

    private var compactText: String {
        if model.tier == .lifetime { return model.tier.title }
        return "\(model.tier.title) · \(countText)"
    }

    private var compactInk: Color {
        if low { return HalfColor.warn }
        return paid ? HalfColor.brassInk : countColor
    }

    private var plateInk: Color {
        paid ? HalfColor.brassInk : HalfColor.ink
    }

    private var plateStroke: Color {
        paid ? HalfColor.brassMid.opacity(0.9) : (depleted ? HalfColor.strokeBright : HalfColor.strokeDim)
    }

    private var compactChip: some View {
        Button(action: openPaywall) {
            Text(compactText)
                .font(HalfType.mono(11, weight: depleted ? .semibold : .medium))
                .foregroundStyle(compactInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.45))
                        .overlay(Capsule().stroke(plateStroke, lineWidth: HalfColor.hairline))
                )
        }
        .buttonStyle(.plain)
    }

    private var fullPlate: some View {
        Button(action: openPaywall) {
            HStack(spacing: 10) {
                Text(model.tier.title)
                    .font(HalfType.serif(13))
                    .foregroundStyle(plateInk)
                Spacer(minLength: 0)
                Text(countText)
                    .font(HalfType.mono(16, weight: .semibold))
                    .foregroundStyle(low ? HalfColor.warn : (paid ? HalfColor.brassInk : countColor))
                if model.tier != .lifetime {
                    Text(L("升级"))
                        .font(HalfType.mono(11, weight: depleted ? .semibold : .regular))
                        .foregroundStyle(depleted ? HalfColor.ink : HalfColor.fog)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: HalfRadius.latch, style: .continuous)
                                .fill(depleted ? HalfChrome.hatchFill : HalfChrome.hatchFillQuiet)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: HalfRadius.latch, style: .continuous)
                                .stroke(depleted ? HalfColor.strokeBright : HalfColor.strokeDim, lineWidth: HalfColor.hairline)
                        )
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: HalfRadius.plate, style: .continuous)
                    .fill(HalfChrome.hatchFillQuiet)
                    .overlay(alignment: .leading) {
                        if paid {
                            Rectangle()
                                .fill(HalfColor.brassMid)
                                .frame(width: 3)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: HalfRadius.plate, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: HalfRadius.plate, style: .continuous)
                            .stroke(plateStroke, lineWidth: HalfColor.hairline)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func openPaywall() {
        model.showPaywall = true
        Haptics.shared.chrome()
    }
}

struct HatchPlate: View {
    var title: String
    var prominent: Bool = true

    var body: some View {
        Text(title)
            .font(HalfType.mono(13, weight: prominent ? .semibold : .regular))
            .foregroundStyle(prominent ? HalfColor.ink : HalfColor.fog)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: HalfRadius.plate, style: .continuous)
                    .fill(prominent ? HalfChrome.hatchFill : HalfChrome.hatchFillQuiet)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HalfRadius.plate, style: .continuous)
                    .stroke(prominent ? HalfColor.strokeBright : HalfColor.strokeDim, lineWidth: HalfColor.hairline)
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(prominent ? 0.18 : 0.08), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: HalfRadius.plate, style: .continuous))
            }
    }
}

typealias ChromePlate = HatchPlate

struct ChromeToast: View {
    var text: String

    var body: some View {
        Text(text)
            .font(HalfType.plate(12))
            .foregroundStyle(Color(white: 0.12))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: HalfRadius.latch, style: .continuous)
                    .fill(HalfChrome.chromeFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: HalfRadius.latch, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            )
    }
}

struct EntitlementMark: View {
    var title: String
    var paid: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .serif))
            .foregroundStyle(paid ? HalfColor.brassInk : Color(white: 0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.45))
                    .overlay(Capsule().stroke(
                        paid ? HalfColor.brassMid.opacity(0.9) : Color(white: 0.38),
                        lineWidth: paid ? 0.8 : 0.8
                    ))
            )
    }
}

struct ChromeConfirm: View {
    var title: String
    var message: String
    var confirmTitle: String
    var cancelTitle: String? = L("取消")
    var confirm: () -> Void
    var cancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { cancel() }
            VStack(spacing: 16) {
                Text(title)
                    .font(HalfType.serif(16))
                    .foregroundStyle(Color.white)
                Text(message)
                    .font(HalfType.mono(12))
                    .foregroundStyle(HalfColor.fog)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    if let cancelTitle {
                        Button {
                            Haptics.shared.chrome()
                            cancel()
                        } label: {
                            HatchPlate(title: cancelTitle, prominent: false)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        Soundboard.shared.play("back")
                        Haptics.shared.latch()
                        confirm()
                    } label: {
                        HatchPlate(title: confirmTitle, prominent: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(HalfColor.cavity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(HalfColor.strokeDim, lineWidth: HalfColor.hairline)
                    )
            )
            .padding(.horizontal, 36)
        }
    }
}

struct MetalSelector: View {
    var labels: [String]
    var selected: Int
    var pick: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { i in
                let on = i == selected
                Button {
                    pick(i)
                    Haptics.shared.chrome()
                } label: {
                    Text(labels[i])
                        .font(HalfType.mono(10, weight: .bold))
                        .foregroundStyle(on ? Color.white : HalfColor.fog.opacity(0.75))
                        .frame(height: 26)
                        .padding(.horizontal, 10)
                        .background {
                            if on {
                                Capsule()
                                    .fill(HalfChrome.latchFill)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.45))
                .overlay(Capsule().stroke(HalfColor.strokeDim, lineWidth: HalfColor.hairline))
        )
    }
}
