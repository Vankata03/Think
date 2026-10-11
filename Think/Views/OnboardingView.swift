//
//  OnboardingView.swift
//  Think
//

import SwiftUI

/// First-launch onboarding (`design/onboarding.md`): the promise, the
/// reminders and their one permission ask, then appearance and two optional
/// switches. Forward only; ends on Today.
struct OnboardingView: View {
    @Environment(PomodoroTimer.self) private var timer
    @Environment(MindfulMinutesStore.self) private var mindfulMinutes
    @Environment(JournalLock.self) private var journalLock
    @Environment(AppIntentRouter.self) private var router
    @Environment(NotificationAccess.self) private var notificationAccess: NotificationAccess?
    @Environment(\.haptics) private var haptics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(Onboarding.completedKey) private var completed = false
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.defaultChoice
    @AppStorage(DailyQuoteNotifier.minutesKey) private var dailyLineMinutes = DailyQuoteNotifier.defaultMinutes
    @AppStorage(RetroReminder.minutesKey) private var retroReminderMinutes = RetroReminder.defaultMinutes

    /// The on-device AI step (#67) joins here on eligible devices.
    private let flow = OnboardingFlow(includesOnDeviceAI: false)
    @State private var step = OnboardingFlow.Step.promise
    @State private var reminders = OnboardingReminderChoice()
    @State private var remindersSaved = false
    /// Applied when onboarding ends, so turning it back off here never
    /// needs the authentication that disabling the lock asks for.
    @State private var lockJournal = false
    @State private var isAdvancing = false

    private var notifications: NotificationAccess { notificationAccess ?? .system }

    var body: some View {
        NavigationStack {
            page
                .id(step)
                .transition(pageTransition)
                .toolbar {
                    if flow.canSkip(step) {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Skip") { skip() }
                                .tint(ThinkColor.label)
                                .disabled(isAdvancing)
                                .accessibilityIdentifier("OnboardingSkip")
                        }
                    }
                }
                .safeAreaBar(edge: .bottom) { bottomBar }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .promise: OnboardingPromiseStep()
        case .reminders: remindersStep
        case .makeItYours: makeItYoursStep
        case .onDeviceAI: EmptyView()
        }
    }

    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity))
    }

    // MARK: Chrome

    private var stepCount: Text {
        Text("Step \(flow.number(of: step)) of \(flow.steps.count)")
    }

    private var bottomBar: some View {
        VStack(spacing: ThinkSpacing.m) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: ThinkSpacing.s) {
                    ForEach(flow.steps, id: \.self) { dot in
                        Circle()
                            .fill(dot == step ? ThinkColor.label : ThinkColor.tertiaryLabel)
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(stepCount)
                .accessibilityIdentifier("OnboardingStepCount")
            }
            Button {
                advance()
            } label: {
                Text(flow.isLast(step) ? String(localized: "Begin practice") : String(localized: "Continue"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .thinkButton(.primary)
            .controlSize(.large)
            .disabled(isAdvancing)
            // With the dots hidden, the primary carries the step count.
            .accessibilityHint(dynamicTypeSize.isAccessibilitySize ? stepCount : Text(verbatim: ""))
            .accessibilityIdentifier("OnboardingPrimary")
        }
        .padding(.horizontal, ThinkSpacing.l)
        .padding(.bottom, ThinkSpacing.s)
    }

    // MARK: Step 2: Reminders

    private var remindersStep: some View {
        Form {
            Section {
                OnboardingSwitchRow(
                    "Daily line", symbol: ThinkSymbol.dailyLine,
                    value: reminders.dailyLine ? time(dailyLineMinutes) : nil,
                    isOn: $reminders.dailyLine)
                    .accessibilityIdentifier("Onboarding.DailyLine")
                OnboardingSwitchRow(
                    "Evening retro", symbol: ThinkSymbol.retro,
                    value: reminders.eveningRetro ? time(retroReminderMinutes) : nil,
                    isOn: $reminders.eveningRetro)
                    .accessibilityIdentifier("Onboarding.EveningRetro")
                OnboardingSwitchRow(
                    "Session end alerts", symbol: ThinkSymbol.focus,
                    detail: Text("When a focus or break interval ends"),
                    isOn: $reminders.sessionEndAlerts)
                    .accessibilityIdentifier("Onboarding.SessionEndAlerts")
            } header: {
                Text("Notifications")
            } footer: {
                Text(reminders.anyOn
                     ? "Change times and switches later in Settings, behind the gear on Progress."
                     : "Turn any of these on in Settings, behind the gear on Progress.")
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Minutes after midnight in the device's clock format.
    private func time(_ minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour().minute())
    }

    // MARK: Step 3: Make it yours

    private var optionalRows: [OnboardingOptionalRow] {
        OnboardingOptionalRow.available(
            healthAvailable: mindfulMinutes.authorization != .unavailable,
            lockAvailable: journalLock.availability.canEnable)
    }

    private var makeItYoursStep: some View {
        Form {
            Section("Appearance") {
                OnboardingAppearanceTiles(selection: $appearance)
            }
            if !optionalRows.isEmpty {
                Section {
                    ForEach(optionalRows, id: \.self) { row in
                        switch row {
                        case .health:
                            OnboardingSwitchRow(
                                "Log focus to Health", symbol: ThinkSymbol.health,
                                detail: Text("Completed sessions become Mindful Minutes"),
                                isOn: healthEnabled)
                                .accessibilityIdentifier("Onboarding.Health")
                        case .journalLock:
                            OnboardingSwitchRow(
                                "Lock journal", symbol: ThinkSymbol.lock,
                                detail: Text(lockDetail),
                                isOn: $lockJournal)
                                .accessibilityIdentifier("Onboarding.LockJournal")
                        }
                    }
                } header: {
                    Text("Optional")
                } footer: {
                    Text("Both stay in Settings.")
                }
            }
        }
        .navigationTitle("Make it yours")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            mindfulMinutes.refreshAuthorization()
            journalLock.refreshAvailability()
        }
    }

    /// Turning it on shows the Health sheet at once, through the path
    /// Settings uses; a denial or error leaves it off.
    private var healthEnabled: Binding<Bool> {
        Binding(
            get: { mindfulMinutes.isEnabled },
            set: { enabled in
                Task { await mindfulMinutes.setEnabled(enabled) }
            })
    }

    private var lockDetail: LocalizedStringKey {
        switch journalLock.availability {
        case .faceID: "Face ID before your writing opens"
        case .touchID: "Touch ID before your writing opens"
        case .opticID: "Optic ID before your writing opens"
        case .passcodeOnly, .passcodeNotSet, .unavailable: "Your passcode before your writing opens"
        }
    }

    // MARK: Actions

    private func advance() {
        guard !isAdvancing else { return }
        haptics.play(.selection)
        guard step == .reminders else {
            moveOn()
            return
        }
        isAdvancing = true
        Task { @MainActor in
            reminders = await OnboardingReminders.commit(
                reminders, permission: notifications.authorizer, timer: timer,
                schedule: notifications.scheduleReminders)
            remindersSaved = true
            isAdvancing = false
            moveOn()
        }
    }

    private func moveOn() {
        guard let next = flow.next(after: step) else {
            finish()
            return
        }
        withAnimation(ThinkMotion.stateAnimation(reduceMotion: reduceMotion)) {
            step = next
        }
    }

    /// Skip never asks. Reminders not yet saved keep their default for a
    /// skip, which is off; the steps already passed keep what they saved.
    private func skip() {
        guard !isAdvancing else { return }
        if !remindersSaved {
            isAdvancing = true
            Task { @MainActor in
                await OnboardingReminders.commit(
                    .allOff, permission: notifications.authorizer, timer: timer, schedule: {})
                finish()
            }
        } else {
            finish()
        }
    }

    private func finish() {
        if lockJournal { journalLock.setEnabled(true) }
        haptics.play(.success)
        router.selectedTab = .today
        completed = true
    }
}

// MARK: - Step 1: Promise

/// The day arc as a picture of a day, the promise and the supporting line,
/// centred in the space above the bottom bar. The arc is dropped at
/// accessibility sizes, where "0 of 3" would teach nothing.
private struct OnboardingPromiseStep: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: ThinkSpacing.l) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        DayArcView(hour: 7, states: .init(question: .next, move: .later, retro: .later))
                            .accessibilityIdentifier("OnboardingDayArc")
                            .padding(.bottom, ThinkSpacing.l)
                    }
                    Text("One line, one question, one move a day.")
                        .font(.think(.lineLarge))
                        .foregroundStyle(ThinkColor.label)
                    Text("A few honest minutes. What you write stays on your device, and syncs through your own iCloud when available.")
                        .font(.think(.body))
                        .foregroundStyle(ThinkColor.secondaryLabel)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, ThinkSpacing.l)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(ThinkColor.background)
    }
}

// MARK: - Switch rows

/// A switch row of onboarding's Forms: a monochrome symbol, the title, a
/// trailing time or a secondary line, in the system green. At accessibility
/// sizes the time moves under the title and the switch under the label
/// (`SettingsToggleStyle`).
private struct OnboardingSwitchRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: LocalizedStringKey
    let symbol: String
    var detail: Text?
    var value: String?
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, symbol: String, detail: Text? = nil, value: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.symbol = symbol
        self.detail = detail
        self.value = value
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Label {
                VStack(alignment: .leading, spacing: ThinkSpacing.xs) {
                    if let value, !dynamicTypeSize.isAccessibilitySize {
                        HStack(alignment: .firstTextBaseline) {
                            Text(title)
                            Spacer(minLength: ThinkSpacing.s)
                            timeText(value)
                        }
                    } else {
                        Text(title)
                        if let value { timeText(value) }
                    }
                    if let detail {
                        detail
                            .font(.think(.secondary))
                            .foregroundStyle(ThinkColor.secondaryLabel)
                    }
                }
            } icon: {
                Image(systemName: symbol)
            }
            .foregroundStyle(ThinkColor.label)
        }
        .toggleStyle(SettingsToggleStyle())
        .tint(ThinkColor.success)
    }

    private func timeText(_ value: String) -> some View {
        Text(value)
            .monospacedDigit()
            .foregroundStyle(ThinkColor.secondaryLabel)
    }
}

// MARK: - Appearance tiles

/// Dark, Auto and Light as pictures of Today (`onboarding.md` 5.1). A tap
/// writes the choice at once, so the screen is its own preview. Side by
/// side, stacked into rows at accessibility sizes.
private struct OnboardingAppearanceTiles: View {
    @Binding var selection: Appearance
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let order: [Appearance] = [.dark, .system, .light]

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: ThinkSpacing.l))
            : AnyLayout(HStackLayout(alignment: .top, spacing: ThinkSpacing.s))
        layout {
            ForEach(Self.order) { option in
                tile(option, stacked: stacked)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ThinkSpacing.s)
    }

    private func tile(_ option: Appearance, stacked: Bool) -> some View {
        let selected = option == selection
        let parts = Group {
            AppearanceThumbnail(option: option)
                .frame(width: stacked ? 44 : 62, height: stacked ? 80 : 112)
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(selected ? ThinkColor.accent : .clear, lineWidth: 2.5)
                        .padding(-4)
                }
                .padding(4)
            Text(option.label)
                .font(.think(.secondary))
                .foregroundStyle(ThinkColor.label)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? ThinkColor.accent : ThinkColor.tertiaryLabel)
        }
        return Button {
            selection = option
        } label: {
            if stacked {
                HStack(spacing: ThinkSpacing.l) { parts }
            } else {
                VStack(spacing: ThinkSpacing.s) { parts }
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("Appearance.\(option.rawValue)")
    }
}

/// A miniature Today drawn in one scheme's fixed colours, split down the
/// middle for Auto, so it reads the same in either appearance.
private struct AppearanceThumbnail: View {
    var option: Appearance

    var body: some View {
        HStack(spacing: 0) {
            switch option {
            case .dark: pane(dark: true)
            case .light: pane(dark: false)
            case .system:
                pane(dark: true).frame(minWidth: 0, maxWidth: .infinity).clipped()
                pane(dark: false).frame(minWidth: 0, maxWidth: .infinity).clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.gray.opacity(0.35), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    /// The thumbnail is drawn in the fixed values of each scheme's tokens.
    private func pane(dark: Bool) -> some View {
        let background = dark ? Color.black : Color(red: 0.949, green: 0.949, blue: 0.969)
        let track = dark ? Color(white: 0.33) : Color(white: 0.78)
        let bar = dark ? Color(white: 0.23) : Color(white: 0.78)
        let card = dark ? Color(white: 0.11) : Color.white
        let accent = dark ? Color(red: 1, green: 0.831, blue: 0.2) : Color(red: 0.949, green: 0.769, blue: 0.11)  // style-exempt: the thumbnail draws both schemes at once
        return VStack(spacing: 5) {
            ZStack(alignment: .topLeading) {
                Circle().trim(from: 0.5, to: 1).stroke(track, lineWidth: 2).frame(width: 34, height: 34)
                Circle().fill(accent).frame(width: 6, height: 6).offset(x: 3, y: 5)
            }
            .frame(width: 34, height: 17, alignment: .top)
            .clipped()
            Capsule().fill(bar).frame(width: 40, height: 4)
            Capsule().fill(bar).frame(width: 30, height: 4)
            RoundedRectangle(cornerRadius: 6).fill(card).frame(width: 50, height: 22)
                .overlay(alignment: .bottom) {
                    Capsule().fill(accent).frame(width: 36, height: 6).padding(.bottom, 4)
                }
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .frame(width: 62)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
}

#Preview {
    OnboardingView()
        .environment(PomodoroTimer())
        .environment(MindfulMinutesStore(client: UnavailableMindfulHealthClient()))
        .environment(JournalLock(authenticator: UnavailableJournalAuthenticator()))
        .environment(AppIntentRouter.shared)
}
