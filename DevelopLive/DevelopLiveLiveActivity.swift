import ActivityKit
import SwiftUI
import WidgetKit

struct DevelopLiveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DevelopActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(red: 0.07, green: 0.06, blue: 0.055))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "halfcam://darkbox"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(expandedTitle(context.state))
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(statusLine(context.state))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            } compactLeading: {
                islandMark
            } compactTrailing: {
                compactTrailing(context.state)
            } minimal: {
                islandMark
            }
            .widgetURL(URL(string: "halfcam://darkbox"))
        }
    }

    private var islandMark: some View {
        Image("IslandMark")
            .resizable()
            .scaledToFill()
            .frame(width: 14, height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
    }

    private func lockScreen(_ context: ActivityViewContext<DevelopActivityAttributes>) -> some View {
        let shown = Array(context.state.items.prefix(3))
        let extra = context.state.count - shown.count
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Text(item.filmName)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    itemStatus(item, languageCode: context.state.languageCode)
                }
            }
            HStack(spacing: 8) {
                Text(statusLine(context.state))
                if extra > 0 {
                    Text(localized("另有 \(extra) 卷", languageCode: context.state.languageCode))
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func itemStatus(_ item: DevelopActivityItem, languageCode: String?) -> some View {
        if item.readyAt <= Date() {
            Text(localized("可取件", languageCode: languageCode))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        } else {
            countdown(item)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func compactTrailing(_ state: DevelopActivityAttributes.ContentState) -> some View {
        if let item = state.soonestLive {
            Text(
                timerInterval: Date()...max(item.readyAt, Date().addingTimeInterval(1)),
                countsDown: true,
                showsHours: false
            )
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 32, alignment: .trailing)
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .semibold))
        }
    }

    @ViewBuilder
    private func expandedTrailing(_ state: DevelopActivityAttributes.ContentState) -> some View {
        if let item = state.soonestLive {
            countdown(item)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func expandedTitle(_ state: DevelopActivityAttributes.ContentState) -> String {
        state.soonestLive?.filmName ?? state.items.first?.filmName ?? "HALF CAM"
    }

    private func statusLine(_ state: DevelopActivityAttributes.ContentState) -> String {
        let value: String.LocalizationValue
        if state.allReady {
            value = state.count > 1 ? "\(state.count) 卷可取件" : "可取件"
        } else {
            value = state.count > 1 ? "暗房显影中 · \(state.count) 卷" : "暗房显影中"
        }
        return localized(value, languageCode: state.languageCode)
    }

    private func localized(_ value: String.LocalizationValue, languageCode: String?) -> String {
        guard let languageCode,
              let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return String(localized: value)
        }
        return String(localized: value, bundle: bundle, locale: Locale(identifier: languageCode))
    }

    private func countdown(_ item: DevelopActivityItem) -> Text {
        Text(
            timerInterval: Date()...max(item.readyAt, Date().addingTimeInterval(1)),
            countsDown: true,
            showsHours: false
        )
        .monospacedDigit()
    }
}
