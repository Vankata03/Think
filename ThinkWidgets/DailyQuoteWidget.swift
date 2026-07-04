//
//  DailyQuoteWidget.swift
//  ThinkWidgets
//

import SwiftUI
import WidgetKit

nonisolated struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: Quote
}

nonisolated enum DailyQuoteTimelineFactory {
    static func entries(startingAt now: Date, calendar: Calendar) -> [QuoteEntry] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return QuoteEntry(date: offset == 0 ? now : day, quote: ContentLibrary.dailyQuote(for: day))
        }
    }
}

nonisolated struct DailyQuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: .now, quote: ContentLibrary.dailyQuote())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        completion(QuoteEntry(date: .now, quote: ContentLibrary.dailyQuote()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        // One entry per day for a week; the quote flips at midnight.
        let entries = DailyQuoteTimelineFactory.entries(startingAt: .now, calendar: .current)
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DailyQuoteWidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    let entry: QuoteEntry
    private let familyOverride: WidgetFamily?

    private let ink = Color(red: 0.07, green: 0.07, blue: 0.08)
    private let brandYellow = Color(red: 1.0, green: 0.83, blue: 0.20)

    init(entry: QuoteEntry, familyOverride: WidgetFamily? = nil) {
        self.entry = entry
        self.familyOverride = familyOverride
    }

    private var family: WidgetFamily {
        familyOverride ?? environmentFamily
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium {
                    ink
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(entry.quote.text)

        case .accessoryRectangular:
            Text(entry.quote.text)
                .font(.headline)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        default:
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(brandYellow)
                    .frame(width: 28, height: 3)
                Text(entry.quote.text)
                    .font(family == .systemSmall ? .footnote : .callout)
                    .fontDesign(.serif)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text(entry.quote.author)
                    .font(.caption2)
                    .foregroundStyle(brandYellow)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct DailyQuoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyQuoteWidget", provider: DailyQuoteProvider()) { entry in
            DailyQuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily line")
        .description("Today's line from Think, on your home and lock screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}

#Preview("Small", as: .systemSmall) {
    DailyQuoteWidget()
} timeline: {
    QuoteEntry(date: .now, quote: ContentLibrary.dailyQuote())
}

#Preview("Rectangular", as: .accessoryRectangular) {
    DailyQuoteWidget()
} timeline: {
    QuoteEntry(date: .now, quote: ContentLibrary.dailyQuote())
}
