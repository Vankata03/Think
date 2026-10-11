//
//  OnboardingTests.swift
//  ThinkTests
//

import Foundation
import Testing
import UserNotifications

@testable import Think

/// Onboarding's Reminders step (`design/onboarding.md` section 4): the
/// permission ask happens once, only from Continue with a switch on, and
/// what is saved follows the answer.
@MainActor
struct OnboardingRemindersTests {

    @Test func continueWithASwitchOnAsksOnceAndSavesWhatIsOnWhenAllowed() async {
        let permission = SpyPermission(status: .notDetermined, grants: true)
        let defaults = makeDefaults()
        let timer = makeTimer()
        var schedules = 0
        let choice = OnboardingReminderChoice(dailyLine: true, eveningRetro: false, sessionEndAlerts: true)

        let saved = await OnboardingReminders.commit(
            choice, permission: permission, defaults: defaults, timer: timer, schedule: { schedules += 1 })

        #expect(permission.requests == 1)
        #expect(saved == choice)
        #expect(defaults.bool(forKey: DailyQuoteNotifier.enabledKey))
        #expect(!defaults.bool(forKey: RetroReminder.enabledKey))
        #expect(timer.sessionEndAlertsEnabled)
        #expect(schedules == 1)
    }

    @Test func aDeniedAskSavesAllThreeOffWithoutScheduling() async {
        let permission = SpyPermission(status: .notDetermined, grants: false)
        let defaults = makeDefaults()
        let timer = makeTimer()
        var schedules = 0

        let saved = await OnboardingReminders.commit(
            OnboardingReminderChoice(), permission: permission, defaults: defaults, timer: timer,
            schedule: { schedules += 1 })

        #expect(permission.requests == 1)
        #expect(saved == .allOff)
        #expect(defaults.object(forKey: DailyQuoteNotifier.enabledKey) as? Bool == false)
        #expect(defaults.object(forKey: RetroReminder.enabledKey) as? Bool == false)
        #expect(!timer.sessionEndAlertsEnabled)
        #expect(schedules == 0)
    }

    @Test func everySwitchOffAsksNothingAndSavesAllOff() async {
        let permission = SpyPermission(status: .notDetermined)
        let defaults = makeDefaults()
        let timer = makeTimer()

        let saved = await OnboardingReminders.commit(
            .allOff, permission: permission, defaults: defaults, timer: timer, schedule: {})

        #expect(permission.requests == 0)
        #expect(saved == .allOff)
        #expect(!defaults.bool(forKey: DailyQuoteNotifier.enabledKey))
        #expect(!defaults.bool(forKey: RetroReminder.enabledKey))
        #expect(!timer.sessionEndAlertsEnabled)
    }

    /// The system shows its prompt only while the answer is undetermined;
    /// an answer given earlier is used as it stands.
    @Test(arguments: [
        (UNAuthorizationStatus.authorized, true), (.provisional, true), (.denied, false),
    ])
    func anEarlierAnswerIsUsedWithoutAsking(status: UNAuthorizationStatus, keepsChoice: Bool) async {
        let permission = SpyPermission(status: status)
        let choice = OnboardingReminderChoice()

        let saved = await OnboardingReminders.commit(
            choice, permission: permission, defaults: makeDefaults(), timer: makeTimer(), schedule: {})

        #expect(permission.requests == 0)
        #expect(saved == (keepsChoice ? choice : .allOff))
    }

    @Test func remindersStartAllOn() {
        let choice = OnboardingReminderChoice()

        #expect(choice.dailyLine && choice.eveningRetro && choice.sessionEndAlerts)
        #expect(choice.anyOn)
        #expect(!OnboardingReminderChoice.allOff.anyOn)
    }
}

/// The paged flow (`design/onboarding.md` sections 2 and 6).
struct OnboardingFlowTests {

    @Test func threeStepsEndOnMakeItYours() {
        let flow = OnboardingFlow(includesOnDeviceAI: false)

        #expect(flow.steps == [.promise, .reminders, .makeItYours])
        #expect(flow.isLast(.makeItYours))
        #expect(!flow.isLast(.reminders))
    }

    @Test func skipShowsOnEveryStepButTheLast() {
        let flow = OnboardingFlow(includesOnDeviceAI: false)

        #expect(flow.canSkip(.promise))
        #expect(flow.canSkip(.reminders))
        #expect(!flow.canSkip(.makeItYours))
    }

    @Test func anEligibleDeviceAddsTheOnDeviceAIStepLast() {
        let flow = OnboardingFlow(includesOnDeviceAI: true)

        #expect(flow.steps == [.promise, .reminders, .makeItYours, .onDeviceAI])
        #expect(flow.canSkip(.makeItYours))
        #expect(flow.isLast(.onDeviceAI))
    }

    @Test func theStepCountIsOneBased() {
        let flow = OnboardingFlow(includesOnDeviceAI: false)

        #expect(flow.number(of: .promise) == 1)
        #expect(flow.number(of: .makeItYours) == 3)
        #expect(flow.next(after: .promise) == .reminders)
        #expect(flow.next(after: .makeItYours) == nil)
    }
}

/// The Optional section of "Make it yours" (`design/onboarding.md` 5.2).
struct OnboardingOptionalRowsTests {

    @Test(arguments: [
        (true, true, [OnboardingOptionalRow.health, .journalLock]),
        (true, false, [.health]),
        (false, true, [.journalLock]),
        (false, false, []),
    ])
    func eachRowShowsOnlyWhereItCanWork(health: Bool, lock: Bool, rows: [OnboardingOptionalRow]) {
        #expect(OnboardingOptionalRow.available(healthAvailable: health, lockAvailable: lock) == rows)
    }
}

@MainActor
private final class SpyPermission: NotificationAuthorizing {
    private var current: UNAuthorizationStatus
    private let grants: Bool
    private(set) var requests = 0

    init(status: UNAuthorizationStatus, grants: Bool = true) {
        current = status
        self.grants = grants
    }

    func status() async -> UNAuthorizationStatus { current }

    func requestAuthorization() async -> Bool {
        requests += 1
        current = grants ? .authorized : .denied
        return grants
    }
}

private func makeDefaults() -> UserDefaults {
    let suiteName = "ThinkTests.Onboarding.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@MainActor
private func makeTimer() -> PomodoroTimer {
    PomodoroTimer(
        systemSideEffectsEnabled: false,
        defaults: makeDefaults(),
        deviceID: UUID(),
        notificationCenter: nil,
        now: { Date(timeIntervalSinceReferenceDate: 10_000) }
    )
}
