//
//  StreakWidget.swift
//  ThinkWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

nonisolated struct StreakWidgetEntry: TimelineEntry {
    let date: Date
    let presentation: StreakPresentation
}

nonisolated enum StreakWidgetTimelineFactory {
    static func entries(
        startingAt now: Date,
        calendar: Calendar,
        defaults: UserDefaults
    ) -> [StreakWidgetEntry] {
        let today = calendar.startOfDay(for: now)
        let dates = [now] + (1...2).compactMap {
            calendar.date(byAdding: .day, value: $0, to: today)
        }
        return dates.map { date in
            StreakWidgetEntry(
                date: date,
                presentation: StreakPresentation.stored(
                    in: defaults,
                    calendar: calendar,
                    now: date
                )
            )
        }
    }
}

nonisolated struct StreakWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakWidgetEntry {
        StreakWidgetEntry(date: .now, presentation: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakWidgetEntry) -> Void) {
        completion(currentEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakWidgetEntry>) -> Void) {
        let entries = StreakWidgetTimelineFactory.entries(
            startingAt: .now,
            calendar: .current,
            defaults: SharedDefaults.appGroup()
        )
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func currentEntry(at date: Date) -> StreakWidgetEntry {
        StreakWidgetEntry(
            date: date,
            presentation: .stored(in: SharedDefaults.appGroup(), now: date)
        )
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    let entry: StreakWidgetEntry
    private let familyOverride: WidgetFamily?

    private let ink = Color(red: 0.07, green: 0.07, blue: 0.08)
    private let brandYellow = Color(red: 1.0, green: 0.83, blue: 0.20)

    init(entry: StreakWidgetEntry, familyOverride: WidgetFamily? = nil) {
        self.entry = entry
        self.familyOverride = familyOverride
    }

    private var family: WidgetFamily {
        familyOverride ?? environmentFamily
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall {
                    ink
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            circularContent

        case .accessoryRectangular:
            rectangularContent

        default:
            smallContent
        }
    }

    private var circularContent: some View {
        Gauge(value: entry.presentation.practiceProgress) {
            Image(systemName: "figure.mind.and.body")
        } currentValueLabel: {
            if entry.presentation.isTodayComplete {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
            } else {
                Text("\(entry.presentation.completedPracticeCount)")
                    .font(.headline.monospacedDigit())
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(brandYellow)
        .widgetAccentable()
        .accessibilityLabel(Text("Daily practice", tableName: "StreakWidget"))
        .accessibilityValue(entry.presentation.todayText)
    }

    private var rectangularContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(entry.presentation.streakText, systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(brandYellow)
            Label(
                entry.presentation.todayText,
                systemImage: entry.presentation.isTodayComplete ? "checkmark.circle.fill" : "circle.dotted"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(entry.presentation.streakText, systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(brandYellow)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Daily practice", tableName: "StreakWidget")
                    Spacer(minLength: 4)
                    Text(entry.presentation.todayText)
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                ProgressView(value: entry.presentation.practiceProgress)
                    .tint(brandYellow)
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)

            Button(intent: StartFocusSessionIntent(preset: .classic)) {
                Label {
                    Text("Start focus", tableName: "AppIntents")
                } icon: {
                    Image(systemName: "timer")
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(brandYellow)
            .foregroundStyle(ink)
        }
        .accessibilityElement(children: .contain)
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: StreakPresentation.widgetKind, provider: StreakWidgetProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("Streak", table: "StreakWidget"))
        .description(
            LocalizedStringResource(
                "Your Think streak and today's practice progress.",
                table: "StreakWidget"
            )
        )
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

#Preview("Circular", as: .accessoryCircular) {
    StreakWidget()
} timeline: {
    StreakWidgetEntry(date: .now, presentation: .placeholder)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    StreakWidget()
} timeline: {
    StreakWidgetEntry(date: .now, presentation: .placeholder)
}

#Preview("Small", as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakWidgetEntry(date: .now, presentation: .placeholder)
}
