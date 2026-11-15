import SwiftUI

struct SteelBezel: View {
    var height: CGFloat = 64

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [Color(white: 0.30), Color(white: 0.16), Color(white: 0.11)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            var rng = SeededRandom(0x57EE1)
            var y: CGFloat = 1
            while y < size.height - 4 {
                let a = 0.04 + rng.unit() * 0.07
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(line, with: .color(Color.white.opacity(a)), lineWidth: 0.6)
                y += 1.15 + rng.unit() * 0.7
            }
            ctx.fill(
                Path(CGRect(x: 0, y: 0, width: size.width, height: 18)),
                with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.16), Color.clear]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: 18)
                )
            )
            ctx.fill(
                Path(CGRect(x: 0, y: size.height - 3, width: size.width, height: 3)),
                with: .color(.black.opacity(0.55))
            )
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

struct BrassPlate<Content: View>: View {
    var compact: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(HalfType.mono(compact ? 10 : 11, weight: .bold))
            .foregroundStyle(Color(white: 0.12))
            .padding(.horizontal, compact ? 7 : 8)
            .padding(.vertical, compact ? 4 : 5)
            .background(
                RoundedRectangle(cornerRadius: HalfRadius.latch, style: .continuous)
                    .fill(HalfChrome.brassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: HalfRadius.latch, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 0.6)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }
}

struct BrassInlay: View {
    var body: some View {
        Rectangle()
            .stroke(
                HalfColor.brass.opacity(0.38),
                style: StrokeStyle(lineWidth: 1.2, dash: [2.2, 2.8])
            )
            .frame(width: 1.2)
            .allowsHitTesting(false)
    }
}
