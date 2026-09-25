// Throwaway Progress + Settings prototype. Sample values; no data writes.
// The accepted decision will be rewritten into production views, not merged from here.

import Charts
import SwiftUI

struct ProgressPrototypeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark
    @State private var journalLocked = false
    private let week = [0, 1, 0, 2, 1, 1, 0]
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var accent: Color {
        colorScheme == .dark
            ? Color(red: 1, green: 212.0 / 255, blue: 51.0 / 255)
            : Color(red: 242.0 / 255, green: 196.0 / 255, blue: 28.0 / 255)
    }
    private var accentInk: Color {
        colorScheme == .dark
            ? accent
            : Color(red: 110.0 / 255, green: 92.0 / 255, blue: 5.0 / 255)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {} label: {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current streak")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text("7")
                                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(accentInk)
                                    Text("days")
                                        .font(.headline)
                                }
                                Text("View calendar")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "flame")
                                .font(.title)
                                .foregroundStyle(accent)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("7 day streak. View calendar")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Weekly review") {
                    NavigationLink {
                        Text("Weekly review destination")
                            .navigationTitle("Weekly review")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("4 of 7 days")
                                .font(.headline)
                            Text("Practised this week")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Practice") {
                    if dynamicTypeSize.isAccessibilitySize {
                        LabeledContent("Practice days", value: "18")
                        LabeledContent("Path steps", value: "6")
                        LabeledContent("Focus sessions", value: "12")
                    } else {
                        HStack(alignment: .top, spacing: 0) {
                            metric("18", "Practice days")
                            metric("6", "Path steps")
                            metric("12", "Focus sessions")
                        }
                        .padding(.vertical, 8)
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        Text("Focus this week: 0, 1, 0, 2, 1, 1, 0 sessions, Monday to Sunday")
                            .font(.subheadline)
                    } else {
                        Chart(Array(week.enumerated()), id: \.offset) { day in
                            BarMark(x: .value("Day", weekdays[day.offset]), y: .value("Sessions", day.element))
                                .foregroundStyle(accent)
                        }
                        .frame(height: 90)
                        .accessibilityLabel("Focus sessions this week: 0, 1, 0, 2, 1, 1, 0")
                    }
                }

                Section("Achievements") {
                    ViewThatFits(in: .horizontal) {
                        earnedMedals
                        earnedMedalsStacked
                    }
                    NavigationLink {
                        PrototypeAchievementsView()
                    } label: {
                        Label("All achievements", systemImage: "medal")
                    }
                }

                Section("Focus history") {
                    historyRow(minutes: "25 min", status: "Completed", date: "Today, 9:40 AM", intention: "Write project outline")
                    historyRow(minutes: "13 min", status: "Partial effort", date: "Yesterday, 4:15 PM", intention: "Read chapter 2")
                    NavigationLink {
                        PrototypeHistoryView(journalLocked: journalLocked)
                    } label: {
                        Label("See all sessions", systemImage: "timer")
                    }
                }
            }
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        PrototypeSettingsView(appearance: $appearance, journalLocked: $journalLocked)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                    }
                    .tint(.primary)
                }
            }
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var earnedMedals: some View {
        HStack(spacing: 12) {
            medal("7-day streak", symbol: "medal")
            medal("First path", symbol: "checkmark.seal")
            medal("First focus", symbol: "timer")
        }
        .padding(.vertical, 8)
    }

    private var earnedMedalsStacked: some View {
        VStack(alignment: .leading, spacing: 12) {
            medal("7-day streak", symbol: "medal")
            medal("First path", symbol: "checkmark.seal")
            medal("First focus", symbol: "timer")
        }
        .padding(.vertical, 8)
    }

    private func medal(_ name: String, symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(accent)
            Text(name)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityValue("Earned")
    }

    private func historyRow(minutes: String, status: String, date: String, intention: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(minutes) · \(status)")
                Text(date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !journalLocked {
                    Text(intention)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PrototypeAchievementsView: View {
    private let items: [(String, String, Bool)] = [
        ("7-day streak", "medal", true), ("21-day streak", "medal", false),
        ("100-day streak", "medal", false), ("First path", "checkmark.seal", true),
        ("First focus", "timer", true), ("10 focus sessions", "timer", false),
        ("50 focus sessions", "timer", false), ("100 focus sessions", "timer", false),
    ]
    var body: some View {
        List {
            Section("Milestones") {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    Label(item.0, systemImage: item.1)
                        .foregroundStyle(item.2 ? .primary : .secondary)
                        .accessibilityValue(item.2 ? "Earned" : "Locked")
                }
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrototypeHistoryView: View {
    let journalLocked: Bool
    var body: some View {
        List {
            Section("This week") {
                LabeledContent("Completed sessions", value: "5")
                LabeledContent("Completed minutes", value: "125 min")
                LabeledContent("Partial effort", value: "13 min")
            }
            Section("Sessions") {
                Text("25 min · Completed · Today, 9:40 AM")
                Text("13 min · Partial effort · Yesterday, 4:15 PM")
                if !journalLocked { Text("Intentions shown only while journal is unlocked") }
            }
        }
        .navigationTitle("Focus history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrototypeSettingsView: View {
    @Binding var appearance: Appearance
    @Binding var journalLocked: Bool
    @State private var dailyReminder = true
    @State private var eveningReminder = false
    @State private var sessionAlerts = true
    @State private var healthLogging = false
    @State private var showIntentionOnLockScreen = false

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.inline)
            }
            Section("Reminders") {
                Toggle(isOn: $dailyReminder) { Label("Daily line", systemImage: "bell").foregroundStyle(.primary) }
                Toggle(isOn: $eveningReminder) { Label("Evening reflection", systemImage: "moon.stars").foregroundStyle(.primary) }
            }
            Section("Focus") {
                Label("Silence distractions", systemImage: "lightbulb").foregroundStyle(.primary)
                Toggle(isOn: $sessionAlerts) { Label("Session end alerts", systemImage: "bell.badge").foregroundStyle(.primary) }
                Toggle(isOn: $healthLogging) { Label("Log focus to Health", systemImage: "heart.text.clipboard").foregroundStyle(.primary) }
            }
            Section {
                LabeledContent { Text("Available") } label: { Label("iCloud sync", systemImage: "icloud").foregroundStyle(.primary) }
            } header: {
                Text("iCloud")
            } footer: {
                Text("Journal changes, including deletions, sync through your own iCloud when available.")
            }
            Section("Privacy and lock") {
                Toggle(isOn: $journalLocked) { Label("Lock journal", systemImage: "lock").foregroundStyle(.primary) }
                Toggle(isOn: $showIntentionOnLockScreen) { Label("Show intention on Lock Screen", systemImage: "rectangle.inset.filled").foregroundStyle(.primary) }
            }
            Section("Data") {
                Label("Export journal", systemImage: "square.and.arrow.up").foregroundStyle(.primary)
                Label("Delete all data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            Section("Feedback") {
                Label("Share an idea", systemImage: "lightbulb").foregroundStyle(.primary)
                Label("Report a problem", systemImage: "exclamationmark.bubble").foregroundStyle(.primary)
                Label("Rate Think", systemImage: "star").foregroundStyle(.primary)
            }
            Section("About") {
                Label("Help & Support", systemImage: "questionmark.circle").foregroundStyle(.primary)
                Label("Privacy Policy", systemImage: "hand.raised").foregroundStyle(.primary)
                LabeledContent("Think", value: "Version 1.3.0")
            }
        }
        .navigationTitle("Settings")
    }
}
