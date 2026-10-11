//
//  SettingsView.swift
//  Think
//

import SwiftUI
import UIKit
import UserNotifications

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// One grouped `Form` pushed from the gear (`progress-settings.md`
/// section 3). Native rows, one monochrome symbol per row, section footers
/// for explanations; the Form supplies the tab-bar inset.
struct SettingsView: View {
    @Environment(MindfulMinutesStore.self) private var mindfulMinutes
    @Environment(CloudBackupState.self) private var cloudBackup
    @Environment(JournalLock.self) private var journalLock
    @Environment(JournalRepository.self) private var journalRepository
    @Environment(AppDataResetCoordinator.self) private var dataReset
    @Environment(PomodoroTimer.self) private var timer
    @Environment(NotificationAccess.self) private var notificationAccess: NotificationAccess?
    @Environment(\.haptics) private var haptics
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.defaultChoice
    @AppStorage(DailyQuoteNotifier.enabledKey) private var dailyLineEnabled = false
    @AppStorage(DailyQuoteNotifier.minutesKey) private var dailyLineMinutes = DailyQuoteNotifier.defaultMinutes
    @AppStorage(RetroReminder.enabledKey) private var retroReminderEnabled = false
    @AppStorage(RetroReminder.minutesKey) private var retroReminderMinutes = RetroReminder.defaultMinutes

    @State private var notificationAuthorization = UNAuthorizationStatus.notDetermined
    @State private var exportItem: ExportItem?
    @State private var showingExportError = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var changingJournalLock = false

    var body: some View {
        Form {
            appearanceSection
            remindersSection
            focusSection
            iCloudSection
            privacySection
            dataSection
            feedbackSection
            aboutSection
        }
        .toggleStyle(SettingsToggleStyle())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .task { refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            // The app refreshes iCloud on activation (ThinkApp); the rest
            // can change in the Settings app while Think is in the background.
            if phase == .active { refreshStatus() }
        }
        .onChange(of: appearance) { haptics.play(.selection) }
        .onChange(of: dailyLineEnabled) {
            haptics.play(.selection)
            refreshNotificationPreferences()
        }
        .onChange(of: dailyLineMinutes) { refreshNotificationPreferences() }
        .onChange(of: retroReminderEnabled) {
            haptics.play(.selection)
            refreshNotificationPreferences()
        }
        .onChange(of: retroReminderMinutes) { refreshNotificationPreferences() }
        .sheet(item: $exportItem, onDismiss: removeTemporaryExport) { item in
            JournalExportSheet(fileURL: item.url)
        }
        .alert("Export failed", isPresented: $showingExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Think could not create the journal export. Try again.")
        }
        .alert("Delete all data?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Everything", role: .destructive) { deleteAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This stops Focus and removes your journal, drafts, intentions, saved practices, progress, and reminders. Journal deletions also sync through your iCloud. Mindful minutes already sent to Health remain in Health. This cannot be undone."
            )
        }
        .alert("Delete failed", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Think could not delete every local record. Try again.")
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("Appearance") {
            AppearanceTiles(selection: $appearance)
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            ReminderRow(
                "Daily line", systemImage: ThinkSymbol.dailyLine,
                isOn: $dailyLineEnabled, minutes: $dailyLineMinutes,
                identifier: "DailyLineReminder", timeIdentifier: "DailyLineTime")
            ReminderRow(
                "Evening retro", systemImage: ThinkSymbol.retro,
                isOn: $retroReminderEnabled, minutes: $retroReminderMinutes,
                identifier: "EveningRetroReminder", timeIdentifier: "EveningRetroTime")

            if notificationAuthorization == .denied {
                VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                    Text("Notifications are off")
                        .font(.think(.heading))
                    Text("The reminder switches can stay on, but Think cannot schedule reminders until notifications are allowed in Settings.")
                        .font(.think(.caption))
                        .foregroundStyle(ThinkColor.secondaryLabel)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("NotificationPermissionDenied")
                Button("Open Settings") { openAppSettings() }
                    .accessibilityIdentifier("OpenNotificationSettings")
            }
        }
    }

    private var focusSection: some View {
        Section {
            NavigationLink {
                SilenceDistractionsView()
            } label: {
                SettingsLabel("Silence distractions", systemImage: "moon")
            }
            .accessibilityIdentifier("SilenceDistractions")

            Toggle(isOn: sessionEndAlertsEnabled) {
                SettingsLabel("Session end alerts", systemImage: "bell")
            }
            .accessibilityIdentifier("SessionEndAlerts")

            Toggle(isOn: mindfulMinutesEnabled) {
                SettingsLabel("Log focus to Health", systemImage: ThinkSymbol.health)
            }
            .disabled(mindfulMinutes.authorization == .unavailable)
            .accessibilityIdentifier("HealthMindfulMinutes")
        } header: {
            Text("Focus")
        } footer: {
            switch mindfulMinutes.authorization {
            case .denied:
                Text("Health access is off. Allow Think to write mindful minutes in the Health app to use this setting.")
            case .unavailable:
                Text("Health logging is unavailable on this device.")
            case .notDetermined, .authorized:
                EmptyView()
            }
        }
    }

    /// Status only. Mirroring is decided when the SwiftData container is
    /// built, so iCloud settings — not an in-app switch — turn sync on and
    /// off.
    private var iCloudSection: some View {
        Section {
            LabeledContent {
                Text(cloudBackup.status.summary)
            } label: {
                SettingsLabel("iCloud sync", systemImage: ThinkSymbol.icloud)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("CloudBackup")
            if cloudBackup.isSyncing {
                Text("Syncing…")
                    .foregroundStyle(ThinkColor.secondaryLabel)
            }
            if let exportedAt = cloudBackup.lastSuccessfulExportDate {
                Text("Last successful upload: \(exportedAt.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(ThinkColor.secondaryLabel)
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text("Journal changes, including deletions, sync through your own iCloud when available. Think has no server or account.")
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        Section {
            Toggle(isOn: journalLockEnabled) {
                SettingsLabel("Lock journal", systemImage: ThinkSymbol.lock)
            }
            .disabled(changingJournalLock || (!journalLock.isEnabled && !journalLock.availability.canEnable))
            .accessibilityIdentifier("LockJournal")
        } header: {
            Text("Privacy and lock")
        } footer: {
            Text(journalLock.availability.settingSubtitle)
        }

        Section {
            Toggle(
                isOn: Binding(
                    get: { timer.showIntentionInLiveActivity },
                    set: { timer.setShowIntentionInLiveActivity($0) }
                )
            ) {
                SettingsLabel("Show intention on Lock Screen", systemImage: "lock.rectangle")
            }
            .accessibilityIdentifier("ShowIntentionOnLockScreen")
        } footer: {
            Text("Off keeps your focus intention out of Live Activities and the Dynamic Island.")
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button(action: exportJournal) {
                SettingsLabel("Export journal", systemImage: ThinkSymbol.share)
            }
            .accessibilityIdentifier("Export journal")

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete all data", systemImage: ThinkSymbol.delete)
                    .foregroundStyle(ThinkColor.destructive)
                    .fullWidthRowSeparator()
            }
            .accessibilityIdentifier("Delete all data")
        }
    }

    private var feedbackSection: some View {
        Section("Feedback") {
            Button {
                sendMail(subject: String(localized: "Think — idea"))
            } label: {
                SettingsLabel("Share an idea", systemImage: "lightbulb")
            }
            .accessibilityIdentifier("ShareIdea")

            Button {
                sendMail(subject: String(localized: "Think — problem"))
            } label: {
                SettingsLabel("Report a problem", systemImage: "exclamationmark.bubble")
            }
            .accessibilityIdentifier("ReportProblem")

            Button {
                haptics.play(.selection)
                Task { await AppReviewRequester.request() }
            } label: {
                SettingsLabel("Rate Think", systemImage: "star")
            }
            .accessibilityIdentifier("RateThink")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Button {
                openURL(SettingsLinks.supportURL)
            } label: {
                SettingsLabel("Help & Support", systemImage: "questionmark.circle")
            }
            .accessibilityIdentifier("HelpAndSupport")

            Button {
                openURL(SettingsLinks.privacyPolicyURL)
            } label: {
                SettingsLabel("Privacy Policy", systemImage: "hand.raised")
            }
            .accessibilityIdentifier("PrivacyPolicy")

            LabeledContent {
                Text(SettingsLinks.versionText(info: Bundle.main.infoDictionary))
            } label: {
                SettingsLabel("Version", systemImage: "info.circle")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("AppVersion")
        }
    }

    private var notifications: NotificationAccess { notificationAccess ?? .system }

    // MARK: - Bindings

    private var journalLockEnabled: Binding<Bool> {
        Binding(
            get: { journalLock.isEnabled },
            set: { enabled in
                guard !changingJournalLock else { return }
                changingJournalLock = true
                Task { @MainActor in
                    let changed = await journalLock.requestEnabled(enabled)
                    changingJournalLock = false
                    haptics.play(changed ? .selection : .warning)
                }
            }
        )
    }

    private var mindfulMinutesEnabled: Binding<Bool> {
        Binding(
            get: { mindfulMinutes.isEnabled },
            set: { enabled in
                haptics.play(.selection)
                Task { await mindfulMinutes.setEnabled(enabled) }
            }
        )
    }

    private var sessionEndAlertsEnabled: Binding<Bool> {
        Binding(
            get: { timer.sessionEndAlertsEnabled },
            set: { enabled in
                haptics.play(.selection)
                Task { @MainActor in
                    notificationAuthorization = await SessionEndAlerts.setEnabled(
                        enabled, timer: timer, permission: notifications.authorizer)
                }
            }
        )
    }

    // MARK: - Actions

    private func refreshStatus() {
        refreshNotificationAuthorization()
        mindfulMinutes.refreshAuthorization()
        journalLock.refreshAvailability()
    }

    private func sendMail(subject: String) {
        let url = SettingsLinks.feedbackMail(
            subject: subject,
            appVersion: SettingsLinks.shortVersion,
            systemVersion: UIDevice.current.systemVersion
        )
        if let url { openURL(url) }
    }

    /// Export copies every entry into a file that leaves the app, so it
    /// authenticates on its own even inside an already-unlocked session.
    private func exportJournal() {
        Task { @MainActor in
            guard await journalLock.authenticateForExport() else {
                haptics.play(.warning)
                return
            }
            do {
                let export = try journalRepository.exportSnapshot()
                exportItem = ExportItem(url: try export.writeToTemporaryFile())
                haptics.play(.success)
            } catch {
                showingExportError = true
                haptics.play(.warning)
            }
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
            try dataReset.reset()
            haptics.play(.success)
        } catch {
            showingDeleteError = true
            haptics.play(.warning)
        }
    }

    private func refreshNotificationAuthorization() {
        Task { @MainActor in
            notificationAuthorization = await notifications.authorizer.status()
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
            notificationAuthorization = await notifications.authorizer.status()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

/// A Settings row label: the title in the label colour beside one
/// monochrome symbol.
private struct SettingsLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(ThinkColor.label)
        .fullWidthRowSeparator()
    }
}

/// A reminder as an alarm: its symbol and title over the time it fires,
/// with the switch beside them. The time is always on show, dimmed while
/// the reminder is off; tapping it opens a wheel, and choosing a time
/// turns the reminder on, as editing an alarm does in Clock.
private struct ReminderRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    @Binding var isOn: Bool
    @Binding var minutes: Int
    let identifier: String
    let timeIdentifier: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editingTime = false

    init(
        _ title: LocalizedStringKey, systemImage: String, isOn: Binding<Bool>, minutes: Binding<Int>,
        identifier: String, timeIdentifier: String
    ) {
        self.title = title
        self.systemImage = systemImage
        _isOn = isOn
        _minutes = minutes
        self.identifier = identifier
        self.timeIdentifier = timeIdentifier
    }

    var body: some View {
        HStack(spacing: ThinkSpacing.m) {
            VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                Label {
                    Text(title)
                        .foregroundStyle(ThinkColor.label)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(isOn ? ThinkColor.accentInk : ThinkColor.secondaryLabel)
                        .symbolEffect(.bounce, options: .nonRepeating, value: isOn)
                }
                .font(.think(.secondary))

                Button {
                    editingTime = true
                } label: {
                    Text($minutes.timeOfDay.wrappedValue, format: .dateTime.hour().minute())
                        .font(.think(.numeral))
                        .foregroundStyle(isOn ? ThinkColor.label : ThinkColor.tertiaryLabel)
                        .contentTransition(.numericText())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Time"))
                .accessibilityValue(Text($minutes.timeOfDay.wrappedValue, format: .dateTime.hour().minute()))
                .accessibilityIdentifier(timeIdentifier)
                .popover(isPresented: $editingTime) {
                    DatePicker("Time", selection: chosenTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding(ThinkSpacing.m)
                        .presentationCompactAdaptation(.popover)
                }
            }
            Spacer(minLength: 0)
            Toggle(isOn: $isOn) { Text(title) }
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, ThinkSpacing.xs)
        .animation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion), value: isOn)
        .fullWidthRowSeparator()
    }

    /// Writing a time switches the reminder on.
    private var chosenTime: Binding<Date> {
        Binding {
            $minutes.timeOfDay.wrappedValue
        } set: { date in
            $minutes.timeOfDay.wrappedValue = date
            if !isOn { isOn = true }
        }
    }
}

/// The system switch, except at accessibility sizes, where a label that
/// wraps would leave the switch floating between its lines: the switch
/// then sits under the label (`progress-settings.md` section 3). Onboarding
/// uses it too (`onboarding.md` section 4).
struct SettingsToggleStyle: ToggleStyle {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: ThinkSpacing.s) {
                configuration.label
                Toggle(isOn: configuration.$isOn) { configuration.label }
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
            }
        } else {
            Toggle(configuration)
                .toggleStyle(.switch)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(MindfulMinutesStore(client: UnavailableMindfulHealthClient()))
    .environment(CloudBackupState(storage: .inMemory))
    .environment(JournalLock(authenticator: UnavailableJournalAuthenticator()))
    .environment(PomodoroTimer())
}
