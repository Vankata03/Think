//
//  StreakCalendarSheet.swift
//  Think
//

import SwiftUI

/// One month of the streak calendar: leading blanks so day 1 lands on
/// its weekday column, then every day of the month.
struct MonthGrid {
    let monthStart: Date
    let leadingBlanks: Int
    let days: [Date]
    let weekdaySymbols: [String]

    init(containing date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        monthStart = start
        leadingBlanks = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        days = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        weekdaySymbols = Array(symbols[first...] + symbols[..<first])
    }
}

/// The streak and the days behind it, one month at a time
/// (`design/progress-settings.md` section 8). Today's streak item and the
/// Progress streak hero both present it as a sheet.
struct StreakCalendarSheet: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics

    @State private var displayedMonth = Date.now
    @State private var monthShift = 0
    @State private var showingShare = false
    /// The sheet's fitted height: content plus the bar and safe area. Six
    /// grid rows are always reserved, so it does not change between months
    /// (`STK-1`). It starts tall enough to lay every row out, because a
    /// lazy list in a short sheet reports an estimate.
    @State private var fittedHeight: CGFloat = 640

    @ScaledMetric(relativeTo: .subheadline) private var scaledDisc: CGFloat = 32

    private let calendar = Calendar.current

    var body: some View {
        let month = StreakMonth(containing: displayedMonth, completedDays: progress.completedDays, calendar: calendar)
        NavigationStack {
            List {
                Section {
                    header
                }
                .listRowBackground(Color.clear)

                Section {
                    pager(month)
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            linearMonth(month)
                        } else {
                            gridMonth(month)
                        }
                    }
                    .id(month.grid.monthStart)
                    .transition(monthTransition)
                }
                .listRowBackground(ThinkColor.surface)
                // One card: no hairline between the pager and the days.
                .listRowSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            // Fitted height: the content plus the bar and safe area around
            // it, which the scroll view reports as content insets (`STK-1`).
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom
            } action: { _, height in
                // Before the first layout the content is empty or estimated.
                if height > 300 { fittedHeight = height }
            }
            .navigationTitle("Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .accessibilityIdentifier("StreakSheet")
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingShare) {
            StreakShareSheet(month: displayedMonth)
        }
    }

    /// Opens at the fitted height, the smaller detent. At accessibility
    /// sizes only `.large` remains, so it opens there; a fitted height
    /// beyond the large detent is clamped to it by the system.
    private var detents: Set<PresentationDetent> {
        guard !dynamicTypeSize.isAccessibilitySize else { return [.large] }
        return [.height(fittedHeight.rounded(.up)), .large]
    }

    private var hasPractised: Bool {
        progress.lastCompletedDay != nil
    }

    // MARK: - Toolbar

    /// "Close" and one plain Share: the sheet has no primary action
    /// (design system 13.5). Nothing to share before the first practice day.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
                .accessibilityIdentifier("CloseStreak")
        }
        if hasPractised {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Share", systemImage: ThinkSymbol.share) {
                    haptics.play(.selection)
                    showingShare = true
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("ShareStreak")
            }
        }
    }

    // MARK: - Header

    /// Flame, numeral and unit on one first baseline (`STK-2`), or the
    /// two-state copy with the flame in `secondaryLabel`. Read as one
    /// element: "12-day streak", "Begin again." or "Start today.".
    private var header: some View {
        let count = progress.displayedStreak
        let presentation = StreakPresentation(streak: count, completedPracticeCount: 0, hasPractised: hasPractised)
        return HStack(alignment: .firstTextBaseline, spacing: ThinkSpacing.s) {
            if count > 0 {
                Image(systemName: ThinkSymbol.streak)
                    .font(.think(.numeral))
                    .foregroundStyle(ThinkColor.accent)
                Text(streakDays(count))
            } else {
                Image(systemName: ThinkSymbol.streak)
                    .font(.think(.body))
                    .foregroundStyle(ThinkColor.secondaryLabel)
                Text(presentation.streakText)
                    .font(.think(.body))
                    .foregroundStyle(ThinkColor.label)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.streakText)
        .accessibilityIdentifier("StreakHeader")
    }

    /// "12 days" as one pluralised string, the number in the numeral role
    /// and the unit in body, so every locale keeps its grammar.
    private func streakDays(_ count: Int) -> AttributedString {
        var text = AttributedString(localized: "streak.days \(count)")
        text.font = .think(.body)
        text.foregroundColor = ThinkColor.label
        if let range = text.range(of: String(count)) {
            text[range].font = .think(.numeral)
        }
        return text
    }

    // MARK: - Pager

    /// Chevrons with titles and the month between them. No swipe: it would
    /// compete with sheet dismissal.
    private func pager(_ month: StreakMonth) -> some View {
        HStack(spacing: ThinkSpacing.s) {
            pagerButton("Previous month", systemImage: "chevron.left", enabled: month.canShowPrevious, shift: -1)
                .accessibilityIdentifier("StreakPreviousMonth")
            Text(month.title)
                .font(.think(.heading))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("StreakMonthTitle")
            pagerButton("Next month", systemImage: "chevron.right", enabled: month.canShowNext, shift: 1)
                .accessibilityIdentifier("StreakNextMonth")
        }
    }

    private func pagerButton(_ title: LocalizedStringKey, systemImage: String, enabled: Bool, shift: Int) -> some View {
        Button {
            shiftMonth(by: shift)
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.think(.body).weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        // Borderless keeps the two buttons separate inside one row.
        .buttonStyle(.borderless)
        .tint(ThinkColor.label)
        .disabled(!enabled)
    }

    private func shiftMonth(by value: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        haptics.play(.selection)
        monthShift = value
        withAnimation(reduceMotion ? ThinkMotion.reduced : ThinkMotion.move) {
            displayedMonth = shifted
        }
        let title = StreakMonth(containing: shifted, completedDays: [], calendar: calendar).title
        AccessibilityNotification.Announcement(title).post()
    }

    /// Slides in from the direction of travel; crossfades under Reduce Motion.
    private var monthTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let insertion: Edge = monthShift < 0 ? .leading : .trailing
        let removal: Edge = monthShift < 0 ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: removal).combined(with: .opacity)
        )
    }

    // MARK: - Grid

    private var discSize: CGFloat { min(scaledDisc, 40) }
    /// Room for today's outer ring: a 2pt gap and a 1.5pt ring each side.
    private var cellHeight: CGFloat { discSize + 8 }

    private func gridMonth(_ month: StreakMonth) -> some View {
        VStack(spacing: ThinkSpacing.s) {
            HStack(spacing: 0) {
                ForEach(Array(month.grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.think(.graphicCaption))
                        .foregroundStyle(ThinkColor.secondaryLabel)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(spacing: ThinkSpacing.xs) {
                ForEach(month.weeks.indices, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(month.weeks[row].indices, id: \.self) { column in
                            dayCell(month.weeks[row][column])
                                .frame(maxWidth: .infinity)
                                .frame(height: cellHeight)
                        }
                    }
                }
            }
        }
        .padding(.vertical, ThinkSpacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("StreakGrid")
    }

    /// The marker table of section 8.2.
    @ViewBuilder
    private func dayCell(_ day: StreakMonth.Day?) -> some View {
        if let day {
            let disc = Text(day.number, format: .number)
                .font(.think(.secondary).weight(day.isPractised ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(dayForeground(day))
                .frame(width: discSize, height: discSize)
                .background {
                    if day.isPractised {
                        Circle().fill(ThinkColor.accent)
                    }
                }
                .overlay {
                    if day.isToday {
                        // Outside a practised disc, past a 2pt gap in the
                        // section colour; on the disc's edge otherwise.
                        Circle()
                            .strokeBorder(ThinkColor.accent, lineWidth: 1.5)
                            .padding(day.isPractised ? -3.5 : 0)
                    }
                }
            // Future days stay out of the accessibility tree.
            if day.isFuture {
                disc.accessibilityHidden(true)
            } else {
                disc.accessibilityLabel(day.accessibilityLabel)
            }
        } else {
            Color.clear
                .accessibilityHidden(true)
        }
    }

    private func dayForeground(_ day: StreakMonth.Day) -> Color {
        if day.isPractised { return ThinkColor.accentOnFill }
        if day.isToday { return ThinkColor.label }
        if day.isFuture { return ThinkColor.tertiaryLabel }
        return ThinkColor.secondaryLabel
    }

    // MARK: - Linear form

    /// At accessibility sizes the grid yields to "n of m days" over a bar;
    /// the practised dates stay available as custom content (section 8.3).
    private func linearMonth(_ month: StreakMonth) -> some View {
        VStack(alignment: .leading, spacing: ThinkSpacing.s) {
            Text(linearCount(month))
            ProgressView(value: Double(month.practisedCount), total: Double(max(month.countedDays, 1)))
                .tint(ThinkColor.accent)
        }
        .padding(.vertical, ThinkSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(month.linearAccessibilityLabel)
        .modifier(PractisedDaysContent(text: month.practisedDaysText))
        .accessibilityIdentifier("StreakLinear")
    }

    private func linearCount(_ month: StreakMonth) -> AttributedString {
        let practised = month.practisedCount
        let counted = month.countedDays
        var text = AttributedString(localized: "streak.linear", defaultValue: "\(practised) of \(counted) days")
        text.font = .think(.body)
        text.foregroundColor = ThinkColor.label
        if let range = text.range(of: String(practised)) {
            text[range].font = .think(.numeral)
        }
        return text
    }
}

/// "Practised days" custom content, only when the month has any.
private struct PractisedDaysContent: ViewModifier {
    let text: String?

    func body(content: Content) -> some View {
        if let text {
            content.accessibilityCustomContent(Text("Practised days"), Text(verbatim: text))
        } else {
            content
        }
    }
}

#Preview {
    StreakCalendarSheet()
        .environment(ProgressStore())
}
