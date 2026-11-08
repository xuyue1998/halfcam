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
                FilmPackSleeve(film: film, width: 102, height: 42)
                    .offset(y: selected ? -38 : -8)
                    .opacity(selected ? 0.92 : 1)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            }
            .frame(width: 110, height: 92)
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
            .fill(style.body)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(style.band)
                    .frame(height: max(3, height * 0.28))
            }
            .overlay(alignment: .top) {
                if showsTopAccent(style.family) {
                    Rectangle()
                        .fill(style.accent)
                        .frame(height: 2)
                }
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
        let radius: CGFloat = compact ? 3 : 2
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.body, style.body.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            familyMarks(style, radius: radius)
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.28)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: radius
                )
            )
            if !compact {
                Text(film.name)
                    .font(.system(size: min(10, height * 0.24), weight: .bold, design: .serif))
                    .foregroundStyle(nameInk(style))
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
                    .frame(width: width - 10)
                    .padding(.top, nameTop(style))
            }
            if compact {
                Text(shortName)
                    .font(.system(size: 7, weight: .bold, design: .serif))
                    .foregroundStyle(nameInk(style))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, height * 0.48)
            }
            Text("\(film.iso)")
                .font(.system(size: compact ? 6 : 7, weight: .bold, design: .monospaced))
                .foregroundStyle(style.ink.opacity(0.88))
                .padding(.top, 3)
                .padding(.trailing, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.black.opacity(0.28), lineWidth: 0.6)
        )
    }

    private var shortName: String {
        film.name.split(separator: " ").first.map(String.init) ?? film.name
    }

    @ViewBuilder
    private func familyMarks(_ style: FilmPackStyle, radius: CGFloat) -> some View {
        switch style.family {
        case .kodakGold, .kodakRed:
            band(style, y: height * 0.42, h: height * 0.30)
        case .fujiGreen, .fujiCyan, .fujiRed, .fujiGray:
            Rectangle()
                .fill(style.accent)
                .frame(height: max(3, height * 0.10))
            band(style, y: height * 0.38, h: height * 0.28)
        case .cineStill:
            Rectangle()
                .fill(style.band)
                .frame(width: width * 0.38, height: height * 1.4)
                .rotationEffect(.degrees(-28))
                .offset(x: -width * 0.08, y: height * 0.08)
        case .visionCan:
            HStack(spacing: 0) {
                Rectangle().fill(style.band).frame(width: width * 0.28)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .kodakBW, .ilfordBW, .fujiBW:
            Rectangle()
                .fill(style.accent)
                .frame(height: max(2, height * 0.08))
            band(style, y: height * 0.40, h: height * 0.28)
        }
    }

    private func band(_ style: FilmPackStyle, y: CGFloat, h: CGFloat) -> some View {
        Rectangle()
            .fill(style.band)
            .frame(height: h)
            .offset(y: y)
    }

    private func nameInk(_ style: FilmPackStyle) -> Color {
        switch style.family {
        case .cineStill, .visionCan: style.ink
        default: style.bandInk
        }
    }

    private func nameTop(_ style: FilmPackStyle) -> CGFloat {
        switch style.family {
        case .cineStill, .visionCan: height * 0.34
        default: height * 0.44
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
