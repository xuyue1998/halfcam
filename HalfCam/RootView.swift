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
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.16), value: model.showDarkroom)
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
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(Color(white: 0.78))
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
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.82), Color(white: 0.42)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 18, height: 6)
                    .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.78))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ChromePlate: View {
    var title: String
    var prominent: Bool = true

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: prominent ? .semibold : .regular, design: .monospaced))
            .foregroundStyle(Color(white: prominent ? 0.92 : 0.62))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: prominent
                                ? [Color(white: 0.28), Color(white: 0.14)]
                                : [Color(white: 0.16), Color(white: 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color(white: prominent ? 0.48 : 0.28), lineWidth: 0.8)
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(prominent ? 0.18 : 0.08), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
    }
}

struct ChromeToast: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(white: 0.12))
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
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.white)
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(white: 0.55))
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    if let cancelTitle {
                        Button {
                            Haptics.shared.chrome()
                            cancel()
                        } label: {
                            ChromePlate(title: cancelTitle, prominent: false)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        Soundboard.shared.play("back")
                        Haptics.shared.latch()
                        confirm()
                    } label: {
                        ChromePlate(title: confirmTitle, prominent: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.06, blue: 0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(white: 0.28), lineWidth: 0.8)
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
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(on ? Color.white : Color(white: 0.42))
                        .frame(height: 26)
                        .padding(.horizontal, 10)
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
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.45))
                .overlay(Capsule().stroke(Color(white: 0.32), lineWidth: 0.8))
        )
    }
}
