//
//  FocusHistoryView.swift
//  Think
//

import SwiftData
import SwiftUI

/// Every retained Focus session, pushed from Progress's "See all sessions"
/// (`design/progress-settings.md` section 2). It opens with this week's
/// totals and the all-time count, then a non-navigating list of sessions,
/// newest first. Intentions appear only while the journal is unlocked.
struct FocusHistoryView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(JournalLock.self) private var lock
    @Environment(JournalRepository.self) private var repository
    @State private var intentions: [String: String] = [:]

    var body: some View {
        let week = progress.weeklySummary(containing: .now, calendar: ProgressOverview.weekCalendar)
        let sessions = Array(progress.focusHistory.reversed())
        List {
            Section {
                LabeledContent("Completed sessions", value: week.completedSessions.formatted())
                LabeledContent("Completed focus minutes", value: week.completedMinutes.formatted())
                LabeledContent(
                    "Partial effort",
                    value: Duration.seconds(week.partialActiveSeconds).formatted(.time(pattern: .minuteSecond)))
            } header: {
                Text("This week")
            } footer: {
                Text("Completed minutes use planned session lengths. Active effort excludes pauses when recorded.")
            }
            Section {
                LabeledContent("All-time completed sessions", value: progress.totalFocusSessions.formatted())
            }
            Section {
                if sessions.isEmpty {
                    Text("No focus sessions yet.")
                        .foregroundStyle(ThinkColor.secondaryLabel)
                }
                ForEach(sessions) { record in
                    FocusSessionRow(record: record, intention: lock.isLocked ? nil : intentions[record.id])
                }
            } header: {
                Text("Session history")
            } footer: {
                Text("History covers the last 365 days. All-time totals are retained. Older actual durations are unknown.")
            }
        }
        .navigationTitle("Focus history")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("FocusHistoryView")
        .task(id: IntentionRequest(sessionIDs: sessions.map(\.id), isLocked: lock.isLocked)) {
            intentions = FocusHistoryIntentions.load(
                sessionIDs: sessions.map(\.id), isLocked: lock.isLocked, repository: repository)
        }
        .onChange(of: lock.isLocked) { _, locked in
            if locked { intentions = [:] }
        }
    }
}

/// What a screen with Focus history rows reloads intentions for.
struct IntentionRequest: Equatable {
    let sessionIDs: [String]
    let isLocked: Bool
}

#Preview {
    let container = try! ModelContainer(
        for: JournalDataStore.schema, configurations: JournalDataStore.configuration(for: .inMemory))
    NavigationStack {
        FocusHistoryView()
    }
    .environment(ProgressStore())
    .environment(JournalLock(authenticator: UnavailableJournalAuthenticator()))
    .environment(JournalRepository(modelContext: container.mainContext, storage: .inMemory))
    .modelContainer(container)
}
