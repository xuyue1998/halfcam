import AVFoundation
import SwiftUI

struct ViewfinderView: View {
    var session: CameraSession
    var hasFilm: Bool
    var hint: String
    var trail: CGFloat
    var curtain: CGFloat = 0
    var allowTapFocus: Bool = true
    var cameraDenied: Bool = false
    var onEmptyTap: (() -> Void)? = nil
    var onPermissionTap: (() -> Void)? = nil
    @State private var localFocus: CGPoint?
    @State private var focusOpacity: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if session.hasCamera {
                    PreviewLayerView(session: session.session, smear: trail)
                } else {
                    SimulatorPreview()
                }
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.clear,
                        Color.black.opacity(0.16)
                    ],
                    center: .center,
                    startRadius: min(geo.size.width, geo.size.height) * 0.62,
                    endRadius: min(geo.size.width, geo.size.height) * 0.98
                )
                .allowsHitTesting(false)
                Rectangle()
                    .strokeBorder(Color.black.opacity(0.45), lineWidth: 1)
                    .allowsHitTesting(false)
                if curtain > 0.001 {
                    VStack(spacing: 0) {
                        Color.black.frame(height: geo.size.height * 0.5 * curtain)
                        Spacer(minLength: 0)
                        Color.black.frame(height: geo.size.height * 0.5 * curtain)
                    }
                    .allowsHitTesting(false)
                }
                if !session.hasCamera, trail > 0.001 {
                    let barW = geo.size.width * 0.55
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: barW, height: geo.size.height)
                        .offset(x: -geo.size.width / 2 - barW / 2 + trail * (geo.size.width + barW))
                        .allowsHitTesting(false)
                }
                if cameraDenied {
                    Color.black.opacity(0.88)
                        .allowsHitTesting(false)
                    Text(L("打开相机权限"))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.12))
                        .padding(.horizontal, 12)
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
                        )
                } else if !hasFilm {
                    Color.black.opacity(0.72)
                        .allowsHitTesting(false)
                    VStack(spacing: 10) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.82), Color(white: 0.42)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 22, height: 7)
                            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
                            .rotationEffect(.degrees(-28), anchor: .leading)
                        Text(L("打开后盖，装入胶片"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .allowsHitTesting(false)
                }
                if let point = session.focusIndicator ?? localFocus {
                    let alpha = session.focusIndicator != nil ? 0.85 : 0.85 * focusOpacity
                    Rectangle()
                        .stroke(Color.white.opacity(alpha), lineWidth: 0.8)
                        .frame(width: 28, height: 28)
                        .position(CGPoint(x: point.x * geo.size.width, y: point.y * geo.size.height))
                        .allowsHitTesting(false)
                }
                if !hint.isEmpty && hasFilm {
                    ChromeToast(text: hint)
                        .allowsHitTesting(false)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { event in
                    if cameraDenied {
                        onPermissionTap?()
                        return
                    }
                    if !hasFilm {
                        onEmptyTap?()
                        return
                    }
                    guard allowTapFocus else { return }
                    if event.location.y > geo.size.height - 48 { return }
                    let nx = min(1, max(0, event.location.x / geo.size.width))
                    let ny = min(1, max(0, event.location.y / geo.size.height))
                    let point = CGPoint(x: nx, y: ny)
                    localFocus = point
                    session.focus(at: point)
                    Haptics.shared.focus()
                    var hard = Transaction()
                    hard.disablesAnimations = true
                    withTransaction(hard) { focusOpacity = 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        guard localFocus == point else { return }
                        withAnimation(.easeOut(duration: 0.2)) { focusOpacity = 0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            if localFocus == point { localFocus = nil }
                        }
                    }
                }
            )
        }
    }
}

struct PreviewLayerView: UIViewRepresentable {
    var session: AVCaptureSession
    var smear: CGFloat = 0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.preview.session = session
        v.preview.videoGravity = .resizeAspectFill
        v.smear = smear
        return v
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.preview.session !== session {
            uiView.preview.session = session
            context.coordinator.didOrient = false
        }
        if abs(uiView.smear - smear) > 0.0005 {
            uiView.smear = smear
        }
        if session.isRunning,
           let conn = uiView.preview.connection,
           conn.isVideoRotationAngleSupported(90),
           !context.coordinator.didOrient || conn.videoRotationAngle != 90 {
            conn.videoRotationAngle = 90
            context.coordinator.didOrient = true
        }
    }

    final class Coordinator {
        var didOrient = false
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    private let bar = UIView()
    var smear: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        bar.backgroundColor = .black
        bar.isUserInteractionEnabled = false
        addSubview(bar)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        preview.frame = bounds
        let w = bounds.width * 0.55
        let x = -w + smear * (bounds.width + w)
        bar.frame = CGRect(x: x, y: 0, width: w, height: bounds.height)
        bar.isHidden = smear < 0.001
    }
}

struct SimulatorPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.08, saturation: 0.22, brightness: 0.72),
                    Color(hue: 0.22, saturation: 0.32, brightness: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 180, height: 180)
                .offset(x: -40, y: -70)
                .blur(radius: 18)
        }
    }
}
