//
//  StreakCardView.swift
//  Think
//

import SwiftUI

/// Share-card designs for the streak, in the same fixed 1080x1920
/// design space as `QuoteCardView`. Two layouts: a big-number streak
/// card, and a month calendar card.
enum StreakCardKind: String, CaseIterable, Identifiable {
    case streak
    case calendar

    var id: String { rawValue }

    var name: String {
        switch self {
        case .streak: String(localized: "Streak")
        case .calendar: String(localized: "Calendar")
        }
    }
}

struct StreakCardView: View {
    let kind: StreakCardKind
    let streak: Int
    let month: Date
    let completedDays: Set<Date>
    let style: CardStyle

    static let designSize = QuoteCardView.designSize

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            style.background

            switch kind {
            case .streak: streakLayout
            case .calendar: calendarLayout
            }
        }
        .frame(width: Self.designSize.width, height: Self.designSize.height)
    }

    private var streakLayout: some View {
        VStack(spacing: 48) {
            Spacer()

            Rectangle()
                .fill(style.accent)
                .frame(width: 120, height: 6)

            Text("\(streak)")
                .font(.system(size: 400, weight: .medium, design: .serif))
                .monospacedDigit()
                .foregroundStyle(style.text)

            Text(streak == 1
                 ? String(localized: "day of deliberate thinking")
                 : String(localized: "days of deliberate thinking"))
                .font(.system(size: 56, weight: .medium, design: .serif))
                .foregroundStyle(style.text)
                .multilineTextAlignment(.center)

            Text("One honest question a day.")
                .font(.system(size: 40, design: .serif))
                .italic()
                .foregroundStyle(style.accent)

            Spacer()

            wordmark
        }
        .padding(.horizontal, 120)
    }

    private var calendarLayout: some View {
        let grid = MonthGrid(containing: month, calendar: calendar)

        return VStack(spacing: 64) {
            Spacer()

            Rectangle()
                .fill(style.accent)
                .frame(width: 120, height: 6)

            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 64, weight: .medium, design: .serif))
                .foregroundStyle(style.text)

            VStack(spacing: 28) {
                HStack(spacing: 0) {
                    ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(style.accent)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 24) {
                    ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
                        Color.clear.frame(height: 88)
                    }
                    ForEach(grid.days, id: \.self) { day in
                        calendarDay(day)
                    }
                }
            }

            Text(streak == 1
                 ? String(localized: "1 day streak")
                 : String(localized: "\(streak) day streak"))
                .font(.system(size: 48, design: .serif))
                .italic()
                .foregroundStyle(style.accent)

            Spacer()

            wordmark
        }
        .padding(.horizontal, 100)
    }

    private func calendarDay(_ day: Date) -> some View {
        let completed = completedDays.contains(calendar.startOfDay(for: day))

        return Text("\(calendar.component(.day, from: day))")
            .font(.system(size: 40, weight: completed ? .bold : .regular, design: .serif))
            .monospacedDigit()
            .foregroundStyle(completed ? style.background : style.text.opacity(0.45))
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background {
                if completed {
                    Circle().fill(style.text)
                }
            }
    }

    private var wordmark: some View {
        Text("THINK")
            .font(.system(size: 32, weight: .medium))
            .kerning(14)
            .foregroundStyle(style.accent)
            .padding(.bottom, 120)
    }
}

#Preview("Streak") {
    StreakCardView(kind: .streak, streak: 12, month: .now, completedDays: [], style: .paper)
        .scaleEffect(0.2)
        .frame(width: 216, height: 384)
}

#Preview("Calendar") {
    StreakCardView(
        kind: .calendar,
        streak: 5,
        month: .now,
        completedDays: Set((0..<5).compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: .now))
        }),
        style: .midnight
    )
    .scaleEffect(0.2)
    .frame(width: 216, height: 384)
}
