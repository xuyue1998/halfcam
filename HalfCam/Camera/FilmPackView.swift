import SwiftUI

struct FilmPackView: View {
    var film: FilmRecipe
    var selected: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                cassette
                    .offset(y: selected ? 6 : 10)
                    .scaleEffect(selected ? 1.04 : 1)
                FilmPackSleeve(film: film, width: 102, height: 48)
                    .offset(y: selected ? -38 : -8)
                    .opacity(selected ? 0.92 : 1)
                    .shadow(color: .black.opacity(0.28), radius: selected ? 5 : 2, y: 2)
            }
            .frame(width: 110, height: 96)
            VStack(spacing: 2) {
                Text(film.name)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(white: 0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
                Text("ISO \(film.iso)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(white: 0.5))
            }
        }
        .frame(width: 110)
    }

    private var cassette: some View {
        ZStack(alignment: .trailing) {
            Image("FilmCassette")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 58)
                .colorMultiply(film.silverCassette ? Color(white: 0.78) : Color.white)
            if film.silverCassette {
                LinearGradient(
                    colors: [Color.white.opacity(0.35), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 96, height: 58)
                .mask(
                    Image("FilmCassette")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 58)
                )
                .allowsHitTesting(false)
            }
            tongue
                .offset(x: 10, y: 4)
        }
        .shadow(color: .black.opacity(selected ? 0.45 : 0.22), radius: selected ? 8 : 3, y: 3)
    }

    private var tongue: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 1,
            bottomTrailingRadius: 1,
            topTrailingRadius: 1
        )
            .fill(film.leaderColor)
            .frame(width: 18, height: 11)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: 2)
            }
    }
}

struct FilmPackChip: View {
    var film: FilmRecipe
    var width: CGFloat = 10
    var height: CGFloat = 14

    var body: some View {
        let style = film.packStyle
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [style.body, style.body.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(style.band)
                    .frame(height: max(3, height * 0.30))
            }
            .overlay(alignment: .top) {
                if showsTopAccent(style.family) {
                    Rectangle()
                        .fill(style.accent)
                        .frame(height: 2)
                }
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 1.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
            )
            .frame(width: width, height: height)
    }
}

struct FilmCassetteBadge: View {
    var film: FilmRecipe
    var width: CGFloat = 54
    var height: CGFloat = 36

    var body: some View {
        FilmPackSleeve(film: film, width: width, height: height, compact: true)
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
    }
}

struct FilmPackSleeve: View {
    var film: FilmRecipe
    var width: CGFloat
    var height: CGFloat
    var compact: Bool = false

    var body: some View {
        let style = film.packStyle
        let radius: CGFloat = compact ? 3 : 2.4
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(bodyFill(style))
            familyMarks(style, radius: radius)
            paperGrain
            cardboardEdge
            topGloss(radius: radius)
            bottomShade(radius: radius)
            nameOnPack(style)
            isoCorner(style)
            if !compact {
                expMark(style)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.black.opacity(0.32), lineWidth: 0.6)
        )
    }

    private var shortName: String {
        film.name.split(separator: " ").first.map(String.init) ?? film.name
    }

    private var bandHeight: CGFloat { height * (compact ? 0.36 : 0.32) }

    private func bodyFill(_ style: FilmPackStyle) -> LinearGradient {
        switch style.family {
        case .visionCan:
            LinearGradient(
                colors: [
                    Color(white: 0.22),
                    Color(red: 0.12, green: 0.13, blue: 0.14),
                    Color(white: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .cineStill:
            LinearGradient(
                colors: [Color(white: 0.16), Color(white: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            LinearGradient(
                colors: [style.body, style.body.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private func familyMarks(_ style: FilmPackStyle, radius: CGFloat) -> some View {
        switch style.family {
        case .kodakGold, .kodakRed:
            band(style)
        case .fujiGreen, .fujiCyan, .fujiRed, .fujiGray:
            Rectangle()
                .fill(style.accent)
                .frame(height: max(3, height * 0.11))
                .frame(maxHeight: .infinity, alignment: .top)
            band(style)
        case .cineStill:
            Rectangle()
                .fill(style.band)
                .frame(width: width * 0.34, height: height * 1.6)
                .rotationEffect(.degrees(-26))
                .offset(x: -width * 0.22)
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1.2, height: height * 1.6)
                .rotationEffect(.degrees(-26))
                .offset(x: -width * 0.06)
        case .visionCan:
            HStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [style.band, style.band.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 0.26)
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1)
                Spacer(minLength: 0)
            }
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                .frame(width: height * 0.42, height: height * 0.42)
                .offset(x: width * 0.28)
        case .kodakBW, .ilfordBW, .fujiBW:
            Rectangle()
                .fill(style.accent)
                .frame(height: max(2, height * 0.08))
                .frame(maxHeight: .infinity, alignment: .top)
            band(style)
        }
    }

    private func band(_ style: FilmPackStyle) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [style.band, style.band.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: bandHeight)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .frame(height: 1)
            }
    }

    private func nameOnPack(_ style: FilmPackStyle) -> some View {
        let onBand = usesBand(style.family)
        return Text(compact ? shortName : film.name)
            .font(.system(size: compact ? 7 : min(10.5, height * 0.20), weight: .bold, design: .serif))
            .foregroundStyle(onBand ? style.bandInk : style.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.52)
            .multilineTextAlignment(.center)
            .frame(width: nameWidth(style), height: onBand ? bandHeight : height * 0.30)
            .offset(x: nameShift(style), y: onBand ? 0 : height * 0.04)
    }

    private func isoCorner(_ style: FilmPackStyle) -> some View {
        Text("\(film.iso)")
            .font(.system(size: compact ? 6 : 7, weight: .bold, design: .monospaced))
            .foregroundStyle(isoInk(style))
            .padding(.top, compact ? 3 : 4)
            .padding(.trailing, compact ? 4 : 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func expMark(_ style: FilmPackStyle) -> some View {
        Text("135")
            .font(.system(size: 6, weight: .bold, design: .monospaced))
            .foregroundStyle(style.ink.opacity(0.55))
            .padding(.top, 4)
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var paperGrain: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(UInt64(bitPattern: Int64(film.id.hashValue)) &+ 17)
            let count = Int(size.width * size.height / 18)
            for _ in 0..<count {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height
                let a = 0.04 + CGFloat(rng.unit()) * 0.05
                ctx.fill(
                    Path(CGRect(x: x, y: y, width: 0.8, height: 0.8)),
                    with: .color(.white.opacity(a))
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.overlay)
    }

    private var cardboardEdge: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 3)
            Spacer(minLength: 0)
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.16)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 2.4)
        }
        .allowsHitTesting(false)
    }

    private func topGloss(radius: CGFloat) -> some View {
        LinearGradient(
            colors: [Color.white.opacity(0.22), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height * 0.30)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: radius
            )
        )
        .allowsHitTesting(false)
    }

    private func bottomShade(radius: CGFloat) -> some View {
        LinearGradient(
            colors: [Color.clear, Color.black.opacity(0.18)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height * 0.28)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: radius,
                bottomTrailingRadius: radius,
                topTrailingRadius: 0
            )
        )
        .allowsHitTesting(false)
    }

    private func usesBand(_ family: FilmPackFamily) -> Bool {
        switch family {
        case .cineStill, .visionCan: false
        default: true
        }
    }

    private func nameWidth(_ style: FilmPackStyle) -> CGFloat {
        switch style.family {
        case .visionCan: width * 0.58
        case .cineStill: width * 0.62
        default: width - 12
        }
    }

    private func nameShift(_ style: FilmPackStyle) -> CGFloat {
        switch style.family {
        case .visionCan: width * 0.10
        case .cineStill: width * 0.10
        default: 0
        }
    }

    private func isoInk(_ style: FilmPackStyle) -> Color {
        switch style.family {
        case .kodakRed, .fujiGreen, .fujiCyan, .fujiRed:
            style.ink.opacity(0.88)
        default:
            style.ink.opacity(0.78)
        }
    }
}

private func showsTopAccent(_ family: FilmPackFamily) -> Bool {
    switch family {
    case .fujiGreen, .fujiCyan, .fujiRed, .fujiGray, .kodakBW, .ilfordBW, .fujiBW:
        true
    default:
        false
    }
}

