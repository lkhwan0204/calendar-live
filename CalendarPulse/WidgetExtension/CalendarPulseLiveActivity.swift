import ActivityKit
import SwiftUI
import WidgetKit

struct CalendarPulseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CalendarActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("캘린더 라이브", systemImage: "calendar.badge.clock")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(remainingText(to: context.state.startDate))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.22), in: Capsule())
                    }
                }

                Text(context.state.title)
                    .font(.title2.weight(.bold))
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(context.state.calendarName, systemImage: "calendar")
                        .lineLimit(1)
                    Label(startDateTimeText(context.state.startDate), systemImage: "clock")
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    ProgressView(value: hourWindowProgress(to: context.state.startDate), total: 1)
                        .tint(.cyan)
                }
            }
            .padding()
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(Color.cyan.opacity(0.2), in: Circle())
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(remainingText(to: context.state.startDate, compact: true))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.22), in: Capsule())
                    }
                    .padding(.trailing, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)
                        Text("\(context.state.calendarName) · \(startDateTimeText(context.state.startDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } compactLeading: {
                Image(systemName: "calendar")
            } compactTrailing: {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    Text(remainingText(to: context.state.startDate, compact: true))
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                Image(systemName: "calendar")
            }
            .widgetURL(URL(string: "calendarpulse://next"))
            .keylineTint(.clear)
        }
    }

    private func remainingText(to startDate: Date, compact: Bool = false) -> String {
        let totalMinutes = Int(ceil(startDate.timeIntervalSinceNow / 60))
        if totalMinutes <= 0 {
            return compact ? "시작" : "시작됨"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if compact {
            return hours > 0 ? "\(hours)시간\(minutes)분" : "\(minutes)분"
        }
        return hours > 0 ? "\(hours)시간 \(minutes)분" : "\(minutes)분"
    }

    private func startTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }

    private func startDateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 a h:mm"
        return formatter.string(from: date)
    }

    private func hourWindowProgress(to startDate: Date) -> Double {
        let remaining = startDate.timeIntervalSinceNow
        let clamped = min(max(remaining, 0), 3600)
        return 1 - (clamped / 3600)
    }
}
