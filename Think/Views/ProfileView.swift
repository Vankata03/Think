//
//  ProfileView.swift
//  Think
//

import SwiftUI
import SwiftData
import StoreKit
import UIKit
import UserNotifications

private enum Feedback {
    static let address = "ivanterziev93@gmail.com"
    static let privacyPolicyURL = URL(string: "https://thinkapp.tech/privacy.html")
    static let supportURL = URL(string: "https://thinkapp.tech/support.html")

    static func mailURL(subject: String) -> URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let body = "\n\n—\nThink \(version), iOS \(UIDevice.current.systemVersion)"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ProfileView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(MindfulMinutesStore.self) private var mindfulMinutes
    @Environment(\.modelContext) private var modelContext
    @Environment(\.haptics) private var haptics
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark
    @AppStorage(DailyQuoteNotifier.enabledKey) private var dailyLineEnabled = false
    @AppStorage(DailyQuoteNotifier.minutesKey) private var dailyLineMinutes = DailyQuoteNotifier.defaultMinutes
    @AppStorage(RetroReminder.enabledKey) private var retroReminderEnabled = false
    @AppStorage(RetroReminder.minutesKey) private var retroReminderMinutes = RetroReminder.defaultMinutes
    @Query(sort: \JournalEntry.date, order: .reverse) private var journalEntries: [JournalEntry]
    @Query(sort: \DailyRetro.date, order: .reverse) private var retrospectives: [DailyRetro]

    @State private var notificationAuthorization = UNAuthorizationStatus.notDetermined
    @State private var exportItem: ExportItem?
    @State private var showingExportError = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false

    private var dailyLineTime: Binding<Date> {
        $dailyLineMinutes.timeOfDay
    }

    private var retroReminderTime: Binding<Date> {
        $retroReminderMinutes.timeOfDay
    }

    private var mindfulMinutesEnabled: Binding<Bool> {
        Binding(
            get: { mindfulMinutes.isEnabled },
            set: { enabled in
                haptics.play(.selection)
                Task {
                    await mindfulMinutes.setEnabled(enabled)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    progressPanel
                    journalPanel
                    settingsPanel
                    feedbackPanel
                    privacyPanel
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 76)
            }
            .task {
                refreshNotificationAuthorization()
                mindfulMinutes.refreshAuthorization()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                refreshNotificationAuthorization()
                mindfulMinutes.refreshAuthorization()
            }
            .sheet(item: $exportItem, onDismiss: removeTemporaryExport) { item in
                JournalExportSheet(fileURL: item.url)
            }
            .alert("Export failed", isPresented: $showingExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Think could not create the journal export. Try again.")
            }
            .alert("Delete all data?", isPresented: $showingDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes journal entries, retrospectives, streaks, and focus history from this device. Mindful minutes already saved to Health stay in Health and can be deleted there. This cannot be undone.")
            }
            .alert("Delete failed", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Think could not delete every local record. Try again.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Profile")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Text("Progress, settings, and your private notes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Progress")
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    profileMetric(
                        value: "\(progress.displayedStreak)",
                        label: "Current streak",
                        systemImage: "flame.fill"
                    )
                    profileMetric(
                        value: "\(progress.totalFocusSessions)",
                        label: "Focus sessions",
                        systemImage: "timer"
                    )
                }

                HStack {
                    Label("Path days completed", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(progress.pathCompletedDays)")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
                .font(.subheadline)

                ProgressView(value: Double(progress.pathCompletedDays) / Double(PathLibrary.deepFocus.steps.count))
                    .tint(.accentColor)
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
        }
        .accessibilityIdentifier("ProfileProgress")
    }

    private var journalPanel: some View {
        NavigationLink {
            JournalView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.closed")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Journal")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Private notes and daily answers")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Journal")
    }

    private var privacyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Privacy")
            VStack(spacing: 0) {
                privacyButton("Export journal", systemImage: "square.and.arrow.up") {
                    exportJournal()
                }
                Divider()
                privacyButton("Delete all data", systemImage: "trash", destructive: true) {
                    showingDeleteConfirmation = true
                }
            }
            .padding(.horizontal, 18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
        }
        .accessibilityIdentifier("Privacy")
    }

    private func profileMetric(value: String, label: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Settings")
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    settingsLabel("Appearance", systemImage: "circle.lefthalf.filled")

                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 10)

                Divider()

                Toggle(isOn: $dailyLineEnabled) {
                    settingsLabel("Daily line notification", systemImage: "bell")
                }
                .toggleStyle(AdaptiveSwitchToggleStyle())
                .padding(.vertical, 10)

                if dailyLineEnabled {
                    Divider()
                    DatePicker(selection: dailyLineTime, displayedComponents: .hourAndMinute) {
                        settingsLabel("Time", systemImage: "clock")
                    }
                    .tint(.accentColor)
                    .padding(.vertical, 10)
                }

                Divider()

                Toggle(isOn: $retroReminderEnabled) {
                    settingsLabel("Evening retrospective reminder", systemImage: "moon.stars")
                }
                .toggleStyle(AdaptiveSwitchToggleStyle())
                .padding(.vertical, 10)

                if retroReminderEnabled {
                    Divider()
                    DatePicker(selection: retroReminderTime, displayedComponents: .hourAndMinute) {
                        settingsLabel("Time", systemImage: "clock")
                    }
                    .tint(.accentColor)
                    .padding(.top, 10)
                }

                if notificationAuthorization == .denied {
                    Divider()
                    notificationDeniedNotice
                }

                Divider()

                Toggle(isOn: mindfulMinutesEnabled) {
                    settingsLabel("Log focus sessions to Health", systemImage: "heart.text.clipboard")
                }
                .toggleStyle(AdaptiveSwitchToggleStyle())
                .disabled(mindfulMinutes.authorization == .unavailable)
                .padding(.vertical, 10)
                .accessibilityIdentifier("HealthMindfulMinutes")

                if mindfulMinutes.authorization == .denied {
                    Text("Health access is off. Allow Think to write mindful minutes in the Health app to use this setting.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 10)
                } else if mindfulMinutes.authorization == .unavailable {
                    Text("Health logging is unavailable on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 10)
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
        }
        .onChange(of: dailyLineEnabled) {
            haptics.play(.selection)
            refreshNotificationPreferences()
        }
        .onChange(of: dailyLineMinutes) {
            refreshNotificationPreferences()
        }
        .onChange(of: retroReminderEnabled) {
            haptics.play(.selection)
            refreshNotificationPreferences()
        }
        .onChange(of: retroReminderMinutes) {
            refreshNotificationPreferences()
        }
    }

    private var notificationDeniedNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notifications are off", systemImage: "bell.slash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("The reminder switches can stay on, but Think cannot schedule reminders until notifications are allowed in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Settings") {
                openAppSettings()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .accessibilityIdentifier("OpenNotificationSettings")
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("NotificationPermissionDenied")
    }

    private var feedbackPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Feedback")
            VStack(spacing: 0) {
                feedbackButton("Share an idea", systemImage: "lightbulb") {
                    sendMail(subject: String(localized: "Think — idea"))
                }
                Divider()
                feedbackButton("Report a problem", systemImage: "exclamationmark.bubble") {
                    sendMail(subject: String(localized: "Think — problem"))
                }
                Divider()
                feedbackButton("Rate Think", systemImage: "star") {
                    requestReview()
                }
                Divider()
                feedbackButton("Help & Support", systemImage: "questionmark.circle") {
                    if let url = Feedback.supportURL {
                        openURL(url)
                    }
                }
                Divider()
                feedbackButton("Privacy Policy", systemImage: "hand.raised") {
                    if let url = Feedback.privacyPolicyURL {
                        openURL(url)
                    }
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.separator.opacity(0.6), lineWidth: 1)
            }
        }
    }

    private func settingsLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
        .font(.subheadline)
    }

    private func feedbackButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func privacyButton(
        _ title: String,
        systemImage: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(destructive ? .red : Color.accentColor)
                    .frame(width: 24)
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(destructive ? .red : .primary)
                Spacer()
                if !destructive {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
    }

    private func sendMail(subject: String) {
        if let url = Feedback.mailURL(subject: subject) {
            openURL(url)
        }
    }

    private func exportJournal() {
        do {
            let export = JournalExport(entries: journalEntries, retrospectives: retrospectives)
            exportItem = ExportItem(url: try export.writeToTemporaryFile())
            haptics.play(.success)
        } catch {
            showingExportError = true
            haptics.play(.warning)
        }
    }

    private func removeTemporaryExport() {
        if let url = exportItem?.url {
            try? FileManager.default.removeItem(at: url)
        }
        exportItem = nil
    }

    private func deleteAllData() {
        do {
            for entry in try modelContext.fetch(FetchDescriptor<JournalEntry>()) {
                modelContext.delete(entry)
            }
            for retrospective in try modelContext.fetch(FetchDescriptor<DailyRetro>()) {
                modelContext.delete(retrospective)
            }
            try modelContext.save()

            progress.reset()
            DailyQuoteNotifier.cancelSchedule()
            RetroReminder.cancelSchedule()
            dailyLineEnabled = false
            dailyLineMinutes = DailyQuoteNotifier.defaultMinutes
            retroReminderEnabled = false
            retroReminderMinutes = RetroReminder.defaultMinutes
            Task {
                await mindfulMinutes.setEnabled(false)
            }
            haptics.play(.success)
        } catch {
            showingDeleteError = true
            haptics.play(.warning)
        }
    }

    private func refreshNotificationAuthorization() {
        Task { @MainActor in
            notificationAuthorization = await NotificationPermission.status()
        }
    }

    private func refreshNotificationPreferences() {
        let dailyEnabled = dailyLineEnabled
        let retroEnabled = retroReminderEnabled
        Task { @MainActor in
            if dailyEnabled {
                await DailyQuoteNotifier.refreshScheduleAsync()
            } else {
                DailyQuoteNotifier.cancelSchedule()
            }

            if retroEnabled {
                await RetroReminder.refreshScheduleAsync()
            } else {
                RetroReminder.cancelSchedule()
            }

            notificationAuthorization = await NotificationPermission.status()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct AdaptiveSwitchToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer()
                switchBody(isOn: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn
                            ? String(localized: "On")
                            : String(localized: "Off"))
    }

    private func switchBody(isOn: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isOn ? Color.accentColor : Color(.tertiarySystemFill))
            .frame(width: 50, height: 30)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(activeThumbColor(isOn: isOn))
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
                    .padding(3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.separator.opacity(isOn ? 0 : 0.6), lineWidth: 1)
            }
    }

    private func activeThumbColor(isOn: Bool) -> Color {
        guard isOn else { return Color(.systemBackground) }
        return colorScheme == .dark ? .black : .white
    }
}

#Preview {
    ProfileView()
        .environment(ProgressStore())
        .environment(MindfulMinutesStore(client: UnavailableMindfulHealthClient()))
        .modelContainer(for: [JournalEntry.self, DailyRetro.self], inMemory: true)
}
