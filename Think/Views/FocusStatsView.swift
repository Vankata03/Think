import Charts
import SwiftUI

struct FocusStatsView: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        let summary = progress.weeklySummary()
        List {
            Section("This week") {
                LabeledContent("Completed sessions", value: summary.completedSessions.formatted())
                LabeledContent("Completed focus minutes", value: summary.completedMinutes.formatted())
                LabeledContent("Partial effort", value: Duration.seconds(summary.partialActiveSeconds).formatted(.time(pattern: .minuteSecond)))
                Text("Completed minutes use planned session lengths. Active effort excludes pauses when recorded.")
                    .font(.footnote).foregroundStyle(.secondary)
                Chart(summary.days, id: \.date) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Sessions", day.completedSessions))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(height: 180)
                .accessibilityLabel("Sessions by day")
                NavigationLink("Weekly review") { WeeklyReviewView() }
            }
            Section {
                LabeledContent("All-time completed sessions", value: progress.totalFocusSessions.formatted())
            }
            Section {
                if progress.focusHistory.isEmpty {
                    Text("No completed focus sessions this week.").foregroundStyle(.secondary)
                }
                ForEach(progress.focusHistory.reversed()) { record in
                    NavigationLink { FocusSessionDetailView(session: record) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.completedAt, format: .dateTime.month().day().hour().minute())
                            Text(record.isCompleted ? String(localized: "Completed") : String(localized: "Partial effort"))
                                .font(.caption).foregroundStyle(.secondary)
                            if let seconds = record.actualActiveSeconds {
                                Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
                                    .font(.subheadline.monospacedDigit())
                            } else { Text("Actual duration unknown").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .accessibilityIdentifier("FocusSession.\(record.id)")
                }
            } header: { Text("Session history") } footer: {
                Text("History covers the last 365 days. All-time totals are retained. Older actual durations are unknown.")
            }
        }
        .navigationTitle("Focus stats").navigationBarTitleDisplayMode(.inline)
    }
}
