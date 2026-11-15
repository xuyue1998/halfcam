import SwiftUI

enum HalfColor {
    static let body = Color(red: 0.08, green: 0.07, blue: 0.06)
    static let cavity = Color(red: 0.07, green: 0.06, blue: 0.055)
    static let tray = Color(red: 0.14, green: 0.11, blue: 0.09)
    static let trayDeep = Color(red: 0.07, green: 0.06, blue: 0.05)
    static let safelight = Color(red: 0.28, green: 0.04, blue: 0.04)
    static let enamel = Color(red: 0.72, green: 0.12, blue: 0.14)
    static let segment = Color(red: 1, green: 0.22, blue: 0.16)
    static let brass = Color(red: 0.68, green: 0.54, blue: 0.40)
    static let brassMid = Color(red: 0.48, green: 0.36, blue: 0.26)
    static let brassDeep = Color(red: 0.28, green: 0.20, blue: 0.14)
    static let brassInk = Color(red: 0.78, green: 0.64, blue: 0.48)
    static let paper = Color(red: 0.93, green: 0.90, blue: 0.82)
    static let ink = Color(white: 0.88)
    static let fog = Color(white: 0.55)
    static let mute = Color(white: 0.32)
    static let warn = Color(red: 1, green: 0.32, blue: 0.22)
    static let steel = Color(white: 0.22)
    static let steelDeep = Color(white: 0.12)
    static let sheen = Color.white.opacity(0.18)
    static let strokeBright = Color(white: 0.48)
    static let strokeDim = Color(white: 0.28)
    static let hairline: CGFloat = 0.8
}

enum HalfRadius {
    static let latch: CGFloat = 3
    static let hatch: CGFloat = 4
    static let plate: CGFloat = 5
    static let finder: CGFloat = 8
    static let sheet: CGFloat = 24
}

enum HalfType {
    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func plate(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

enum HalfChrome {
    static var hatchFill: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.28), Color(white: 0.14)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var hatchFillQuiet: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.16), Color(white: 0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var latchFill: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.82), Color(white: 0.42)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var chromeFill: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.78), Color(white: 0.52), Color(white: 0.64)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var brassFill: LinearGradient {
        LinearGradient(
            colors: [HalfColor.brass, HalfColor.brassMid, HalfColor.brassDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func memberFill(_ tier: MembershipTier) -> LinearGradient {
        tier == .free ? chromeFill : brassFill
    }

    static func memberLatch(_ tier: MembershipTier) -> LinearGradient {
        tier == .free ? latchFill : brassFill
    }

    static var steelFill: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.26), Color(white: 0.12), Color(white: 0.18)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var enamelFill: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 0.82, green: 0.18, blue: 0.16),
                HalfColor.enamel,
                Color(red: 0.48, green: 0.08, blue: 0.10)
            ],
            center: UnitPoint(x: 0.42, y: 0.32),
            startRadius: 2,
            endRadius: 34
        )
    }
}
