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
                    ThinkColor.surface
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
            Image(systemName: ThinkSymbol.practice)
        } currentValueLabel: {
            if entry.presentation.isTodayComplete {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
            } else {
                Text("\(entry.presentation.completedPracticeCount)")
                    .font(.headline.monospacedDigit())
                    .fontDesign(.rounded)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(ThinkColor.accent)
        .widgetAccentable()
        .accessibilityLabel(Text("Daily practice", tableName: "StreakWidget"))
        .accessibilityValue(entry.presentation.todayText)
    }

    private var rectangularContent: some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
            streakLabel
            Label {
                Text(entry.presentation.todayText)
                    .foregroundStyle(ThinkColor.secondaryLabel)
            } icon: {
                Image(systemName: entry.presentation.isTodayComplete ? ThinkSymbol.done : ThinkSymbol.pathStepPending)
                    .foregroundStyle(
                        entry.presentation.isTodayComplete ? ThinkColor.success : ThinkColor.secondaryLabel
                    )
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.s) {
            streakLabel
                .lineLimit(1)

            VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                // Stacked, not side by side: in bg and de, and at larger
                // text sizes, the value clipped against the title (WID-1).
                VStack(alignment: .leading, spacing: 0) {
                    Text("Daily practice", tableName: "StreakWidget")
                        .foregroundStyle(ThinkColor.label)
                    Text(entry.presentation.todayText)
                        .monospacedDigit()
                        .foregroundStyle(ThinkColor.secondaryLabel)
                }
                .font(.caption.weight(.semibold))
                ProgressView(value: entry.presentation.practiceProgress)
                    .tint(ThinkColor.accent)
                    .widgetAccentable()
            }

            Spacer(minLength: ThinkSpacing.xs)

            Button(intent: StartFocusSessionIntent(preset: .classic)) {
                Label {
                    Text("Start focus", tableName: "AppIntents")
                } icon: {
                    Image(systemName: ThinkSymbol.focus)
                }
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ThinkColor.accent)
            .foregroundStyle(ThinkColor.accentOnFill)
            .widgetAccentable()
        }
        .accessibilityElement(children: .contain)
    }

    /// Text in `label`; the flame is the evidence, so it carries the accent
    /// while a streak runs and goes quiet when it reads "Start today." or
    /// "Begin again.".
    private var streakLabel: some View {
        Label {
            Text(entry.presentation.streakText)
                .foregroundStyle(ThinkColor.label)
        } icon: {
            Image(systemName: ThinkSymbol.streak)
                .foregroundStyle(entry.presentation.streak > 0 ? ThinkColor.accent : ThinkColor.secondaryLabel)
                .widgetAccentable(entry.presentation.streak > 0)
        }
        .font(.headline)
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

#Preview("Small, begin again", as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakWidgetEntry(
        date: .now,
        presentation: StreakPresentation(streak: 0, completedPracticeCount: 0, hasPractised: true)
    )
    StreakWidgetEntry(
        date: .now,
        presentation: StreakPresentation(streak: 12, completedPracticeCount: 1)
    )
}
