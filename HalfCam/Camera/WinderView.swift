import SwiftUI
import UIKit

struct WinderView: UIViewRepresentable {
    var enabled: Bool
    var onTick: (CGFloat) -> Void
    var onAdvanced: () -> Void

    func makeUIView(context: Context) -> WinderKnob {
        let view = WinderKnob()
        view.onTick = onTick
        view.onAdvanced = onAdvanced
        view.isKnobEnabled = enabled
        return view
    }

    func updateUIView(_ uiView: WinderKnob, context: Context) {
        uiView.onTick = onTick
        uiView.onAdvanced = onAdvanced
        uiView.isKnobEnabled = enabled
    }
}

final class WinderKnob: UIView {
    var onTick: ((CGFloat) -> Void)?
    var onAdvanced: (() -> Void)?
    var isKnobEnabled = true {
        didSet {
            if oldValue && !isKnobEnabled {
                speed = 0
                accumulated = 0
                springing = false
            }
            pin.backgroundColor = (isKnobEnabled ? UIColor(red: 0.72, green: 0.12, blue: 0.14, alpha: 1) : UIColor(white: 0.22, alpha: 1)).cgColor
        }
    }

    private let disc = CALayer()
    private let pin = CALayer()
    private let flash = CALayer()
    private var angle: CGFloat = 0
    private var speed: CGFloat = 0
    private var accumulated: CGFloat = 0
    private var lastPoint: CGPoint = .zero
    private var lastPanTime: CFTimeInterval = 0
    private var panning = false
    private var lastTooth = 0
    private var link: CADisplayLink?
    private var lastStamp: CFTimeInterval = 0
    private var springing = false
    private let teeth = 18
    private let friction: CGFloat = 3.4
    private let springK: CGFloat = 28
    private let springD: CGFloat = 7.2
    private let threshold = CGFloat(AppConst.advanceRadians)
    private let dead: CGFloat = 8

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isExclusiveTouch = true
        disc.contentsGravity = .resize
        disc.magnificationFilter = .linear
        disc.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.addSublayer(disc)
        pin.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        pin.cornerRadius = 6
        pin.backgroundColor = UIColor(red: 0.72, green: 0.12, blue: 0.14, alpha: 1).cgColor
        disc.addSublayer(pin)
        flash.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        flash.backgroundColor = UIColor.white.cgColor
        flash.opacity = 0
        layer.addSublayer(flash)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        disc.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        disc.position = center
        disc.cornerRadius = side / 2
        disc.masksToBounds = true
        if disc.contents == nil || abs(disc.bounds.width - side) > 0.5 {
            disc.contents = Self.makeDisc(size: side * UIScreen.main.scale, teeth: teeth)?.cgImage
        }
        let pinS = max(10, side * 0.136)
        pin.bounds = CGRect(x: 0, y: 0, width: pinS, height: pinS)
        pin.cornerRadius = pinS / 2
        pin.position = CGPoint(x: side / 2, y: side * 0.22)
        flash.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        flash.position = center
        flash.cornerRadius = side / 2
        CATransaction.commit()
        applyAngle()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            link?.invalidate()
            link = nil
        } else if link == nil {
            let l = CADisplayLink(target: self, selector: #selector(step(_:)))
            if #available(iOS 15.0, *) {
                l.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
            }
            l.add(to: .main, forMode: .common)
            link = l
            lastStamp = CACurrentMediaTime()
        }
    }

    deinit { link?.invalidate() }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard isKnobEnabled else { return }
        let p = g.location(in: self)
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let dist = hypot(p.x - c.x, p.y - c.y)
        let now = CACurrentMediaTime()
        switch g.state {
        case .began:
            panning = true
            springing = false
            lastPoint = p
            lastPanTime = now
            speed = 0
        case .changed:
            if dist < dead {
                lastPoint = p
                return
            }
            let da = Self.delta(from: lastPoint, to: p, center: c)
            lastPoint = p
            let dt = CGFloat(max(1.0 / 240.0, now - lastPanTime))
            lastPanTime = now
            if da > 0.0004 {
                angle += da
                accumulated += da
                speed = da / dt
                tryAdvance()
                if isKnobEnabled { checkTeeth() }
                applyAngle()
            } else if da < -0.0004 {
                speed *= 0.72
            }
        default:
            panning = false
            if isKnobEnabled, accumulated < threshold, abs(speed) < 1.4 {
                springing = true
                speed = min(speed, 1.6)
            }
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = CGFloat(min(0.024, now - lastStamp))
        lastStamp = now
        guard !panning else { return }
        if springing {
            let force = -springK * accumulated - springD * speed
            speed += force * dt
            let da = speed * dt
            accumulated += da
            angle += da
            if accumulated <= 0.002 {
                accumulated = 0
                speed = 0
                springing = false
            }
            applyAngle()
            return
        }
        if flash.opacity > 0.02 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            flash.opacity = Float(CGFloat(flash.opacity) * exp(-14 * dt))
            if flash.opacity < 0.03 { flash.opacity = 0 }
            CATransaction.commit()
        }
        if abs(speed) > 0.002 {
            if speed > 0 {
                let da = speed * dt
                angle += da
                accumulated += da
                tryAdvance()
                if !isKnobEnabled { return }
            }
            speed *= exp(-friction * dt)
            if abs(speed) < 0.01 { speed = 0 }
            if isKnobEnabled { checkTeeth() }
            applyAngle()
        } else if isKnobEnabled, accumulated > 0.002, accumulated < threshold {
            springing = true
            speed = 0
        }
    }

    private func checkTeeth() {
        let tooth = Int((angle / (2 * .pi) * CGFloat(teeth)).rounded(.down))
        if tooth != lastTooth {
            lastTooth = tooth
            if isKnobEnabled { onTick?(abs(speed)) }
        }
    }

    private func tryAdvance() {
        guard isKnobEnabled, accumulated >= threshold else { return }
        let extra = accumulated - threshold
        angle -= extra
        accumulated = 0
        speed = 0
        lastTooth = Int((angle / (2 * .pi) * CGFloat(teeth)).rounded(.down))
        isKnobEnabled = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flash.opacity = 0.28
        CATransaction.commit()
        applyAngle()
        onAdvanced?()
    }

    private func applyAngle() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        disc.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        CATransaction.commit()
    }

    private static func delta(from a: CGPoint, to b: CGPoint, center c: CGPoint) -> CGFloat {
        let v1x = a.x - c.x
        let v1y = a.y - c.y
        let v2x = b.x - c.x
        let v2y = b.y - c.y
        let cross = v1x * v2y - v1y * v2x
        let dot = v1x * v2x + v1y * v2y
        return atan2(cross, dot)
    }

    private static func makeDisc(size: CGFloat, teeth: Int) -> UIImage? {
        let side = max(8, size)
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        return renderer.image { ctx in
            let g = ctx.cgContext
            let r = side / 2 - 1
            let c = CGPoint(x: bounds.midX, y: bounds.midY)
            g.translateBy(x: c.x, y: c.y)
            let body = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
            g.setFillColor(UIColor(white: 0.16, alpha: 1).cgColor)
            g.fillEllipse(in: body)
            g.saveGState()
            g.addEllipse(in: body)
            g.clip()
            g.setFillColor(UIColor(white: 0.32, alpha: 0.55).cgColor)
            g.fillEllipse(in: CGRect(x: -r * 0.7, y: -r * 1.05, width: r * 1.4, height: r * 0.9))
            g.restoreGState()
            g.setStrokeColor(UIColor(white: 0.72, alpha: 1).cgColor)
            g.setLineWidth(2.4 * side / 88)
            g.strokeEllipse(in: CGRect(x: -r + 1, y: -r + 1, width: r * 2 - 2, height: r * 2 - 2))
            g.setStrokeColor(UIColor(white: 0.38, alpha: 1).cgColor)
            g.setLineWidth(1.4 * side / 88)
            g.strokeEllipse(in: CGRect(x: -r * 0.52, y: -r * 0.52, width: r * 1.04, height: r * 1.04))
            g.setStrokeColor(UIColor(white: 0.48, alpha: 1).cgColor)
            g.setLineWidth(1.7 * side / 88)
            for i in 0..<teeth {
                let a = CGFloat(i) / CGFloat(teeth) * 2 * .pi
                g.move(to: CGPoint(x: cos(a) * r * 0.58, y: sin(a) * r * 0.58))
                g.addLine(to: CGPoint(x: cos(a) * r * 0.92, y: sin(a) * r * 0.92))
            }
            g.strokePath()
            g.setFillColor(UIColor(white: 0.78, alpha: 1).cgColor)
            g.fillEllipse(in: CGRect(x: -r * 0.20, y: -r * 0.20, width: r * 0.40, height: r * 0.40))
        }
    }
}

struct RewindKnobView: UIViewRepresentable {
    var enabled: Bool
    var onTick: (CGFloat) -> Void
    var onProgress: (CGFloat) -> Void
    var onComplete: () -> Void

    func makeUIView(context: Context) -> RewindKnob {
        let view = RewindKnob()
        view.onTick = onTick
        view.onProgress = onProgress
        view.onComplete = onComplete
        view.isKnobEnabled = enabled
        return view
    }

    func updateUIView(_ uiView: RewindKnob, context: Context) {
        uiView.onTick = onTick
        uiView.onProgress = onProgress
        uiView.onComplete = onComplete
        uiView.isKnobEnabled = enabled
    }
}

final class RewindKnob: UIView {
    var onTick: ((CGFloat) -> Void)?
    var onProgress: ((CGFloat) -> Void)?
    var onComplete: (() -> Void)?
    var isKnobEnabled = false {
        didSet {
            if !isKnobEnabled {
                accumulated = 0
                speed = 0
                sounding = false
                Soundboard.shared.stop("rewind")
                Haptics.shared.grainStop(fade: true)
            }
            pin.backgroundColor = (isKnobEnabled ? UIColor(red: 0.72, green: 0.12, blue: 0.14, alpha: 1) : UIColor(white: 0.22, alpha: 1)).cgColor
            alpha = 1
        }
    }

    private let disc = CALayer()
    private let pin = CALayer()
    private var angle: CGFloat = 0
    private var accumulated: CGFloat = 0
    private var speed: CGFloat = 0
    private var lastPoint: CGPoint = .zero
    private var lastPanTime: CFTimeInterval = 0
    private var panning = false
    private var lastTooth = 0
    private var sounding = false
    private var link: CADisplayLink?
    private var lastStamp: CFTimeInterval = 0
    private let teeth = 12
    private let threshold: CGFloat = .pi * 2
    private let dead: CGFloat = 6

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isExclusiveTouch = true
        disc.contentsGravity = .resize
        disc.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.addSublayer(disc)
        pin.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        pin.cornerRadius = 4
        pin.backgroundColor = UIColor(white: 0.22, alpha: 1).cgColor
        disc.addSublayer(pin)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        disc.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        disc.position = CGPoint(x: bounds.midX, y: bounds.midY)
        disc.cornerRadius = side / 2
        disc.masksToBounds = true
        if disc.contents == nil {
            disc.contents = Self.makeDisc(size: side * UIScreen.main.scale)?.cgImage
        }
        let pinS = max(7, side * 0.18)
        pin.bounds = CGRect(x: 0, y: 0, width: pinS, height: pinS)
        pin.cornerRadius = pinS / 2
        pin.position = CGPoint(x: side / 2, y: side * 0.18)
        CATransaction.commit()
        applyAngle()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            link?.invalidate()
            link = nil
        } else if link == nil {
            let l = CADisplayLink(target: self, selector: #selector(step(_:)))
            l.add(to: .main, forMode: .common)
            link = l
            lastStamp = CACurrentMediaTime()
        }
    }

    deinit { link?.invalidate() }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard isKnobEnabled else { return }
        let p = g.location(in: self)
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let dist = hypot(p.x - c.x, p.y - c.y)
        let now = CACurrentMediaTime()
        switch g.state {
        case .began:
            panning = true
            lastPoint = p
            lastPanTime = now
            speed = 0
            if !sounding {
                sounding = true
                Soundboard.shared.play("rewind")
                Haptics.shared.grainStart(duration: 2.4)
            }
        case .changed:
            if dist < dead {
                lastPoint = p
                return
            }
            let signed = WinderKnobDelta.from(lastPoint, to: p, center: c)
            lastPoint = p
            let dt = CGFloat(max(1.0 / 240.0, now - lastPanTime))
            lastPanTime = now
            if signed > 0.0004 {
                angle += signed
                accumulated += signed
                speed = signed / dt
                onProgress?(min(1, accumulated / threshold))
                checkTeeth()
                applyAngle()
                tryComplete()
            } else if signed < -0.0004 {
                speed *= 0.72
            }
        default:
            panning = false
            if accumulated < threshold {
                sounding = false
                Soundboard.shared.stop("rewind")
                Haptics.shared.grainStop()
            }
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = CGFloat(min(0.024, now - lastStamp))
        lastStamp = now
        guard !panning, isKnobEnabled else { return }
        if accumulated >= threshold { return }
        if speed > 0.4 {
            let da = speed * dt
            angle += da
            accumulated += da
            speed *= exp(-2.4 * dt)
            onProgress?(min(1, accumulated / threshold))
            checkTeeth()
            applyAngle()
            tryComplete()
        } else if accumulated > 0.002 {
            let next = accumulated * exp(-7.5 * dt)
            let da = next - accumulated
            accumulated = next
            angle += da
            if accumulated < 0.01 {
                accumulated = 0
                speed = 0
            }
            onProgress?(min(1, accumulated / threshold))
            applyAngle()
        }
    }

    private func checkTeeth() {
        let tooth = Int((angle / (2 * .pi) * CGFloat(teeth)).rounded(.down))
        if tooth != lastTooth {
            lastTooth = tooth
            onTick?(max(speed, 1))
        }
    }

    private func tryComplete() {
        guard isKnobEnabled, accumulated >= threshold else { return }
        isKnobEnabled = false
        sounding = false
        applyAngle()
        onProgress?(1)
        onComplete?()
    }

    private func applyAngle() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        disc.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        CATransaction.commit()
    }

    private static func makeDisc(size: CGFloat) -> UIImage? {
        let side = max(8, size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { ctx in
            let g = ctx.cgContext
            let r = side / 2 - 1
            g.translateBy(x: side / 2, y: side / 2)
            g.setFillColor(UIColor(white: 0.18, alpha: 1).cgColor)
            g.fillEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
            let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceGray(),
                colors: [UIColor(white: 0.42, alpha: 1).cgColor, UIColor(white: 0.14, alpha: 1).cgColor] as CFArray,
                locations: [0, 1]
            )
            if let grad {
                g.saveGState()
                g.addEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
                g.clip()
                g.drawLinearGradient(grad, start: CGPoint(x: 0, y: -r), end: CGPoint(x: 0, y: r), options: [])
                g.restoreGState()
            }
            g.setStrokeColor(UIColor(white: 0.72, alpha: 1).cgColor)
            g.setLineWidth(1.6 * side / 40)
            g.strokeEllipse(in: CGRect(x: -r + 1, y: -r + 1, width: r * 2 - 2, height: r * 2 - 2))
            g.setFillColor(UIColor(white: 0.82, alpha: 1).cgColor)
            g.fill(CGRect(x: -1.6, y: -r * 0.62, width: 3.2, height: r * 0.42))
            g.setFillColor(UIColor(white: 0.78, alpha: 1).cgColor)
            g.fillEllipse(in: CGRect(x: -r * 0.18, y: -r * 0.18, width: r * 0.36, height: r * 0.36))
        }
    }
}

enum WinderKnobDelta {
    static func from(_ a: CGPoint, to b: CGPoint, center c: CGPoint) -> CGFloat {
        let v1x = a.x - c.x
        let v1y = a.y - c.y
        let v2x = b.x - c.x
        let v2y = b.y - c.y
        return atan2(v1x * v2y - v1y * v2x, v1x * v2x + v1y * v2y)
    }
}

struct ShutterHitView: UIViewRepresentable {
    var onDown: () -> Void
    var onPress: () -> Void
    var onRelease: () -> Void
    var onEVChanged: (CGFloat) -> Void
    var onEVEnded: () -> Void
    var onResetEV: () -> Void

    func makeUIView(context: Context) -> ShutterHit {
        let view = ShutterHit()
        view.onDown = onDown
        view.onPress = onPress
        view.onRelease = onRelease
        view.onEVChanged = onEVChanged
        view.onEVEnded = onEVEnded
        view.onResetEV = onResetEV
        return view
    }

    func updateUIView(_ uiView: ShutterHit, context: Context) {
        uiView.onDown = onDown
        uiView.onPress = onPress
        uiView.onRelease = onRelease
        uiView.onEVChanged = onEVChanged
        uiView.onEVEnded = onEVEnded
        uiView.onResetEV = onResetEV
    }
}

final class ShutterHit: UIView {
    var onDown: (() -> Void)?
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onEVChanged: ((CGFloat) -> Void)?
    var onEVEnded: (() -> Void)?
    var onResetEV: (() -> Void)?
    private var lastTap: CFTimeInterval = 0
    private var down = false
    private var draggingEV = false
    private var resetting = false
    private var start: CGPoint = .zero
    private var fired = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isExclusiveTouch = true
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        down = true
        draggingEV = false
        fired = false
        resetting = false
        start = touch.location(in: self)
        let now = CACurrentMediaTime()
        if now - lastTap < 0.28 {
            resetting = true
            down = false
            lastTap = 0
            onResetEV?()
            return
        }
        lastTap = now
        onDown?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard down, !resetting, let touch = touches.first else { return }
        let p = touch.location(in: self)
        let dy = p.y - start.y
        if !draggingEV, abs(dy) >= 10 {
            draggingEV = true
        }
        if draggingEV {
            onEVChanged?(dy)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        finish(press: !draggingEV && down && !resetting)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        finish(press: false)
    }

    private func finish(press: Bool) {
        if resetting {
            resetting = false
            down = false
            draggingEV = false
            return
        }
        if draggingEV {
            onEVEnded?()
        } else if press, !fired {
            fired = true
            onPress?()
        }
        if down { onRelease?() }
        down = false
        draggingEV = false
    }
}
