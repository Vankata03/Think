//
//  FocusStatsView.swift
//  Think
//

import Charts
import SwiftUI

struct FocusStatsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("This week")
                    .font(.largeTitle.bold())

                summaryCards

                VStack(alignment: .leading, spacing: 16) {
                    Text("Sessions by day")
                        .font(.headline)

                    Chart(weekdays) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Sessions", day.sessions)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(5)
                        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
                        .accessibilityValue(day.sessions.formatted())
                    }
                    .chartXAxis {
                        AxisMarks(values: weekdays.map(\.date)) { _ in
                            AxisGridLine().foregroundStyle(.clear)
                            AxisTick().foregroundStyle(.secondary)
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                    }
                    .frame(height: 220)
                    .accessibilityLabel("Sessions by day")

                    if weeklySessions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No completed focus sessions this week.")
                                .font(.subheadline.weight(.semibold))
                            Text("Finish a work session to see it here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle("Focus stats")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var weekInterval: DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: .now)
            ?? DateInterval(start: calendar.startOfDay(for: .now), duration: 7 * 24 * 60 * 60)
    }

    @ViewBuilder
    private var summaryCards: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                cards
            }
        } else {
            HStack(spacing: 12) {
                cards
            }
        }
    }

    @ViewBuilder
    private var cards: some View {
        FocusStatCard(
            value: weeklySessions.count,
            label: "Sessions",
            systemImage: "checkmark.circle"
        )
        FocusStatCard(
            value: weeklyMinutes,
            label: "Focus minutes",
            systemImage: "timer"
        )
    }

    private var weeklySessions: [FocusSessionRecord] {
        progress.focusSessions(in: weekInterval)
    }

    private var weeklyMinutes: Int {
        weeklySessions.reduce(0) { $0 + $1.durationMinutes }
    }

    private var weekdays: [FocusStatsDay] {
        (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekInterval.start),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }
            let sessions = progress.focusSessions(in: DateInterval(start: day, end: nextDay))
            return FocusStatsDay(
                date: day,
                sessions: sessions.count
            )
        }
    }
}

private struct FocusStatsDay: Identifiable {
    let date: Date
    let sessions: Int

    var id: Date { date }
}

private struct FocusStatCard: View {
    let value: Int
    let label: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text(value, format: .number)
                .font(.title.bold())
                .monospacedDigit()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        FocusStatsView()
    }
    .environment(ProgressStore())
}
