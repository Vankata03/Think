//
//  JournalRow.swift
//  Think
//

import SwiftUI

/// What one compact Journal row says (`design/journal.md` section 4):
/// the kind badge, the first sentence as the title, the time and the rest
/// of the text, then mood and primary theme.
struct JournalRowContent: Equatable {
    enum Kind: Equatable {
        case answer, note, retro, weeklyReview, focusNote

        init(stored kind: String) {
            switch kind {
            case JournalEntry.kindQuestion: self = .answer
            case JournalEntry.kindWeeklyReview: self = .weeklyReview
            case JournalEntry.kindFocus: self = .focusNote
            default: self = .note
            }
        }

        /// The badge's accessibility label.
        var name: String {
            switch self {
            case .answer: String(localized: "Answer")
            case .note: String(localized: "Note")
            case .retro: String(localized: "Retro")
            case .weeklyReview: String(localized: "Weekly review")
            case .focusNote: String(localized: "Focus note")
            }
        }

        var symbol: String {
            switch self {
            case .answer: ThinkSymbol.question
            case .note: ThinkSymbol.note
            case .retro: ThinkSymbol.retro
            case .weeklyReview: ThinkSymbol.weeklyReview
            case .focusNote: ThinkSymbol.focus
            }
        }
    }

    let kind: Kind
    let title: String
    /// Nil for a weekly review, which belongs to a week rather than a moment.
    let time: String?
    let rest: String
    /// A version that is not its day's primary, shown by a search or filter
    /// (`design/journal.md` section 6).
    let isOtherVersion: Bool
    let mood: Mood?
    /// The primary theme; the secondary shows only on the detail.
    let theme: Theme?

    init(_ entry: JournalRepository.EntrySnapshot, isOtherVersion: Bool = false) {
        kind = Kind(stored: entry.kind)
        let zone = Self.zone(entry.timeZoneIdentifier)
        if kind == .weeklyReview {
            var style = Date.FormatStyle.dateTime.day().month(.wide)
            style.timeZone = zone
            title = String(localized: "Week of \(entry.date.formatted(style))")
            time = nil
            rest = Self.flatten([entry.text, entry.nextIntention ?? ""])
        } else {
            (title, rest) = Self.split([entry.text], fallback: kind.name)
            time = Self.time(entry.date, zone: zone)
        }
        self.isOtherVersion = isOtherVersion
        mood = Mood(stored: entry.mood)
        theme = entry.themes.primary
    }

    init(_ retro: JournalRepository.RetroSnapshot, isOtherVersion: Bool = false) {
        kind = .retro
        (title, rest) = Self.split([retro.wentWell, retro.improve, retro.tomorrow, retro.tomorrowIntention ?? ""], fallback: kind.name)
        time = Self.time(retro.date, zone: Self.zone(retro.timeZoneIdentifier))
        self.isOtherVersion = isOtherVersion
        mood = Mood(stored: retro.mood)
        theme = retro.themes.primary
    }

    /// Mood and primary theme joined by " · ", or nil when both are empty.
    var moodAndTheme: String? {
        let parts = [mood?.label, theme?.label].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The whole row as one accessibility element: kind, title, time,
    /// rest, mood and theme.
    var accessibilityLabel: String {
        [kind.name, title, time, isOtherVersion ? String(localized: "Other version") : nil, rest, mood?.label, theme?.label]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// The first sentence of the first non-empty text, cut at its first
    /// line break, and everything after it on one line.
    private static func split(_ texts: [String], fallback: String) -> (title: String, rest: String) {
        let trimmed = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let index = trimmed.firstIndex(where: { !$0.isEmpty }) else { return (fallback, "") }
        let text = trimmed[index]
        let line = text.prefix { !$0.isNewline }
        var end = line.endIndex
        line.enumerateSubstrings(in: line.startIndex..<line.endIndex, options: [.bySentences, .substringNotRequired]) { _, range, _, stop in
            end = range.upperBound
            stop = true
        }
        let title = text[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, flatten([String(text[end...])] + trimmed[(index + 1)...]))
    }

    /// Joins texts on one line: line breaks and runs of spaces become one
    /// space, empty texts drop out.
    private static func flatten(_ texts: [String]) -> String {
        texts
            .flatMap { $0.split(whereSeparator: \.isWhitespace) }
            .joined(separator: " ")
    }

    private static func time(_ date: Date, zone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = zone
        return date.formatted(style)
    }

    private static func zone(_ identifier: String?) -> TimeZone {
        identifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }
}

/// The compact Journal row. Pushing a detail and swipe actions belong to
/// the list that shows it.
struct JournalRow: View {
    let content: JournalRowContent

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .footnote) private var badgeSize: CGFloat = 28
    @ThinkSpacing.Scaled(ThinkSpacing.xs) private var lineGap
    @ThinkSpacing.Scaled(ThinkSpacing.m) private var badgeGap

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: lineGap))
            : AnyLayout(HStackLayout(alignment: .top, spacing: badgeGap))
        layout {
            Image(systemName: content.kind.symbol)
                .font(.think(.caption))
                .foregroundStyle(ThinkColor.secondaryLabel)
                .frame(width: badgeSize, height: badgeSize)
                .background(ThinkColor.fill, in: .rect(cornerRadius: ThinkSpacing.s, style: .continuous))
            VStack(alignment: .leading, spacing: lineGap) {
                Text(content.title)
                    .font(.think(.heading))
                    .foregroundStyle(ThinkColor.label)
                    .lineLimit(stacked ? 3 : 1)
                if stacked {
                    if let time = timeLine { Text(time) }
                    if !content.rest.isEmpty {
                        Text(content.rest).foregroundStyle(ThinkColor.secondaryLabel).lineLimit(2)
                    }
                } else if let line = secondLine {
                    Text(line).lineLimit(1)
                }
                if let moodAndTheme = content.moodAndTheme {
                    HStack(alignment: .firstTextBaseline, spacing: lineGap) {
                        if let mood = content.mood { Image(systemName: mood.systemImage) }
                        Text(moodAndTheme)
                    }
                    .font(.think(.caption))
                    .foregroundStyle(ThinkColor.secondaryLabel)
                }
            }
            .font(.think(.secondary))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    /// The time in `label`, then "Other version" in `secondaryLabel`.
    private var timeLine: AttributedString? {
        guard content.time != nil || content.isOtherVersion else { return nil }
        var line = AttributedString(content.time ?? "")
        line.foregroundColor = ThinkColor.label
        if content.isOtherVersion {
            var marker = AttributedString((content.time == nil ? "" : "  ") + String(localized: "Other version"))
            marker.foregroundColor = ThinkColor.secondaryLabel
            line += marker
        }
        return line
    }

    /// The time line, two spaces, then the rest in `secondaryLabel`.
    private var secondLine: AttributedString? {
        var line = timeLine ?? AttributedString()
        if !content.rest.isEmpty {
            var rest = AttributedString((line.characters.isEmpty ? "" : "  ") + content.rest)
            rest.foregroundColor = ThinkColor.secondaryLabel
            line += rest
        }
        return line.characters.isEmpty ? nil : line
    }
}
