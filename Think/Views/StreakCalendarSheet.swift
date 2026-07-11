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

struct StreakCalendarSheet: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics

    @State private var displayedMonth = Date.now
    @State private var showingShare = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    streakHeader
                    calendarCard
                    shareButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .navigationTitle("Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showingShare) {
            StreakShareSheet(month: displayedMonth)
        }
    }

    private var streakHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(progress.displayedStreak > 0 ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(progress.displayedStreak)")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(streakCaption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(progress.displayedStreak > 0
                            ? String(localized: "\(progress.displayedStreak) day streak")
                            : streakCaption)
    }

    /// Streak-zero copy follows the "no guilt" principle: a fresh user
    /// is invited to start, a lapsed one to begin again.
    private var streakCaption: String {
        if progress.displayedStreak > 0 { return String(localized: "streak") }
        return progress.lastCompletedDay == nil
            ? String(localized: "start today")
            : String(localized: "begin again")
    }

    private var calendarCard: some View {
        let grid = MonthGrid(containing: displayedMonth, calendar: calendar)

        return VStack(spacing: 16) {
            monthHeader
            HStack {
                ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 36)
                }
                ForEach(grid.days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                haptics.play(.selection)
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous month")

            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()

            Button {
                haptics.play(.selection)
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentMonthDisplayed)
            .accessibilityLabel("Next month")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.accentColor)
    }

    private func dayCell(_ day: Date) -> some View {
        let completed = progress.hasCompleted(day)
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > Date.now && !isToday

        return Text("\(calendar.component(.day, from: day))")
            .font(.subheadline.weight(completed ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(dayForeground(completed: completed, isFuture: isFuture))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background {
                if completed {
                    Circle().fill(Color.accentColor.opacity(0.18))
                }
            }
            .overlay {
                if isToday {
                    Circle().stroke(Color.accentColor, lineWidth: 1.5)
                }
            }
            .accessibilityLabel(accessibilityLabel(for: day, completed: completed))
    }

    private func dayForeground(completed: Bool, isFuture: Bool) -> Color {
        if completed { return .accentColor }
        if isFuture { return Color(.tertiaryLabel) }
        return .secondary
    }

    private func accessibilityLabel(for day: Date, completed: Bool) -> Text {
        let date = day.formatted(.dateTime.month(.wide).day())
        return completed
            ? Text(String(localized: "\(date), completed"))
            : Text(verbatim: date)
    }

    private var isCurrentMonthDisplayed: Bool {
        calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month)
    }

    private func shiftMonth(by value: Int) {
        if let shifted = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = shifted
        }
    }

    private var shareButton: some View {
        Button {
            haptics.play(.selection)
            showingShare = true
        } label: {
            Label("Share your streak", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.accentColor)
    }
}

#Preview {
    StreakCalendarSheet()
        .environment(ProgressStore())
}
