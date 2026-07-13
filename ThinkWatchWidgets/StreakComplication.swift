//
//  StreakComplication.swift
//  ThinkWatchWidgets
//

import SwiftUI
import WidgetKit

nonisolated struct StreakEntry: TimelineEntry {
    let date: Date
    let presentation: StreakPresentation
}

nonisolated struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, presentation: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: .now, presentation: currentPresentation(at: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        // The displayed streak only changes at midnight (today becomes
        // yesterday), so one entry now plus the next two midnights is enough.
        let calendar = Calendar.current
        let now = Date.now
        var entries = [StreakEntry(date: now, presentation: currentPresentation(at: now))]
        for offset in 1...2 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) {
                entries.append(StreakEntry(date: midnight, presentation: currentPresentation(at: midnight)))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func currentPresentation(at date: Date) -> StreakPresentation {
        .stored(in: SharedDefaults.appGroup(), now: date)
    }
}

struct StreakComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    private let brandYellow = Color(red: 1.0, green: 0.83, blue: 0.20)

    var body: some View {
        content
            .containerBackground(for: .widget) { }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label(inlineText, systemImage: "flame.fill")

        case .accessoryCorner:
            Text("\(entry.presentation.streak)")
                .font(.title.bold())
                .monospacedDigit()
                .foregroundStyle(entry.presentation.streak > 0 ? brandYellow : .secondary)
                .widgetLabel {
                    Label(
                        entry.presentation.streak == 1
                            ? String(localized: "day streak")
                            : String(localized: "days streak"),
                        systemImage: "flame.fill"
                    )
                }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Think", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(brandYellow)
                Text(entry.presentation.streakText)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        default: // .accessoryCircular
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(entry.presentation.streak > 0 ? brandYellow : .secondary)
                Text("\(entry.presentation.streak)")
                    .font(.title3.bold())
                    .monospacedDigit()
            }
        }
    }

    private var inlineText: String { entry.presentation.streakText }
}

struct StreakComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakComplication", provider: StreakProvider()) { entry in
            StreakComplicationView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your Think practice streak, on the watch face.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

#Preview("Circular", as: .accessoryCircular) {
    StreakComplication()
} timeline: {
    StreakEntry(date: .now, presentation: .placeholder)
    StreakEntry(date: .now, presentation: StreakPresentation(streak: 0, completedPracticeCount: 0))
}
