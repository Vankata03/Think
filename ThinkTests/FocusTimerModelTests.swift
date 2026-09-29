//
//  FocusTimerModelTests.swift
//  ThinkTests
//

import Foundation
import Testing
import UserNotifications
@testable import Think

@MainActor
struct FocusTimerModelTests {

    // MARK: - Session end alerts

    @Test func startingASessionNeverAsksForNotificationPermission() async {
        let center = SpyNotificationCenter()
        let timer = makeTimer(center: center)

        timer.start()
        await timer.settleNotificationScheduling()

        #expect(center.authorizationRequests == 0)
    }

    @Test func adoptingARunningRemoteSessionNeverAsksForNotificationPermission() async {
        let clock = TestClock()
        let center = SpyNotificationCenter()
        let remote = makeTimer(clock: clock)
        remote.start()
        let timer = makeTimer(center: center, clock: clock)

        #expect(timer.apply(remote.syncState))
        await timer.settleNotificationScheduling()

        #expect(timer.isRunning)
        #expect(center.authorizationRequests == 0)
    }

    @Test func sessionEndAlertsAreOnUntilSwitchedOff() {
        let (defaults, cleanUp) = isolatedDefaults()
        defer { cleanUp() }

        #expect(makeTimer(defaults: defaults).sessionEndAlertsEnabled)

        makeTimer(defaults: defaults).setSessionEndAlertsEnabled(false)

        #expect(!makeTimer(defaults: defaults).sessionEndAlertsEnabled)
    }

    @Test func withAlertsOnTheWorkAndBreakEndsAreAnnounced() async {
        let clock = TestClock()
        let center = SpyNotificationCenter()
        let timer = makeTimer(center: center, clock: clock)

        timer.start()
        await timer.settleNotificationScheduling()

        // Work ends at 25 minutes, the break 5 minutes after.
        #expect(center.pendingIntervals == [25 * 60, 30 * 60])
    }

    @Test func withAlertsOffNoPhaseEndIsAnnounced() async {
        let (defaults, cleanUp) = isolatedDefaults()
        defer { cleanUp() }
        let center = SpyNotificationCenter()
        let timer = makeTimer(center: center, defaults: defaults)
        timer.setSessionEndAlertsEnabled(false)

        timer.start()
        await timer.settleNotificationScheduling()

        #expect(center.addedRequests == 0)
        #expect(timer.isRunning)
    }

    @Test func switchingAlertsOffMidSessionWithdrawsTheScheduledOnes() async {
        let center = SpyNotificationCenter()
        let timer = makeTimer(center: center)
        timer.start()
        await timer.settleNotificationScheduling()

        timer.setSessionEndAlertsEnabled(false)
        await timer.settleNotificationScheduling()
        #expect(center.pending.isEmpty)

        timer.setSessionEndAlertsEnabled(true)
        await timer.settleNotificationScheduling()
        #expect(center.pendingIntervals == [25 * 60, 30 * 60])
    }

    // MARK: - Wheel

    @Test(arguments: [(23, 25), (22, 20), (3, 5), (0, 5), (125, 120), (50, 50), (5, 5), (120, 120)])
    func workSnapsToTheNearestFiveMinuteStepWithinFiveToOneTwenty(stored: Int, wheel: Int) {
        #expect(PomodoroTimer.Preset.wheel(workMinutes: stored, restMinutes: 5).workMinutes == wheel)
    }

    @Test(arguments: [(0, 1), (1, 1), (7, 7), (30, 30), (45, 30)])
    func breakStaysWithinOneToThirtyMinutes(stored: Int, wheel: Int) {
        #expect(PomodoroTimer.Preset.wheel(workMinutes: 25, restMinutes: stored).restMinutes == wheel)
    }

    @Test func theWheelOffersFiveMinuteWorkStepsAndMinuteBreakSteps() {
        #expect(PomodoroTimer.Preset.wheelWorkMinutes.first == 5)
        #expect(PomodoroTimer.Preset.wheelWorkMinutes.last == 120)
        #expect(PomodoroTimer.Preset.wheelWorkMinutes.count == 24)
        #expect(PomodoroTimer.Preset.wheelRestMinutes == Array(1...30))
    }

    @Test func twentyFiveFiveIsClassicFiftyTenIsLongAndTheRestAreCustom() {
        let timer = makeTimer()

        timer.selectDuration(workMinutes: 50, restMinutes: 10)
        #expect(timer.preset == .long)

        timer.selectDuration(workMinutes: 25, restMinutes: 5)
        #expect(timer.preset == .classic)

        timer.selectDuration(workMinutes: 25, restMinutes: 10)
        #expect(timer.preset.isCustom)

        timer.selectDuration(workMinutes: 30, restMinutes: 5)
        #expect(timer.preset.isCustom)
        #expect(timer.remainingSeconds == 30 * 60)
    }

    @Test func aStoredOffStepLengthShowsAndStartsAsTheNearestStep() {
        let (defaults, cleanUp) = isolatedDefaults()
        defer { cleanUp() }
        // Possible from the old one-minute pickers.
        #expect(makeTimer(defaults: defaults).selectCustom(workMinutes: 23, restMinutes: 5))

        let timer = makeTimer(defaults: defaults)
        #expect(timer.wheelPreset.workMinutes == 25)

        timer.startFromWheel()

        #expect(timer.preset.workMinutes == 25)
        #expect(timer.phaseTotalSeconds == 25 * 60)
        #expect(timer.remainingSeconds == 25 * 60)
        // Saved as the new work length, not only used once.
        #expect(makeTimer(defaults: defaults).preset == .classic)
    }

    @Test func theDurationCannotChangeOnceASessionHasStarted() {
        let timer = makeTimer()
        timer.start()
        timer.pause()

        timer.selectDuration(workMinutes: 50, restMinutes: 10)

        #expect(timer.preset == .classic)
        #expect(timer.currentSessionID != nil)
    }

    // MARK: - Path-step entry

    @Test func aPathStepSetsTheWheelAndIntentionWithoutStarting() {
        let timer = makeTimer()

        timer.prepareForPathStep(workMinutes: 10, title: "One hard problem", journalLocked: false)

        #expect(timer.preset.workMinutes == 10)
        #expect(timer.preset.restMinutes == 5)
        #expect(timer.remainingSeconds == 10 * 60)
        #expect(timer.intention == "One hard problem")
        #expect(!timer.isRunning)
        #expect(timer.currentSessionID == nil)
    }

    @Test func aPathStepOfTwentyFiveMinutesIsTheClassicPreset() {
        let timer = makeTimer()
        timer.selectDuration(workMinutes: 50, restMinutes: 10)

        timer.prepareForPathStep(workMinutes: 25, title: "Protect a block", journalLocked: false)

        #expect(timer.preset == .classic)
    }

    @Test func aPathStepLeavesTheIntentionAloneWhileTheJournalIsLocked() {
        let timer = makeTimer()
        timer.setIntention("Earlier private intention")

        timer.prepareForPathStep(workMinutes: 50, title: "Protect a block", journalLocked: true)

        #expect(timer.preset.workMinutes == 50)
        #expect(timer.preset.restMinutes == 5)
        #expect(timer.intention == "Earlier private intention")
    }

    @Test func aPathStepChangesNothingWhileASessionIsRunning() {
        let timer = makeTimer()
        timer.setIntention("Current work")
        timer.start()
        let sessionID = timer.currentSessionID
        var recorded: [FocusSessionRecord] = []
        timer.onSessionRecorded = { recorded.append($0) }

        timer.prepareForPathStep(workMinutes: 10, title: "One hard problem", journalLocked: false)

        #expect(timer.isRunning)
        #expect(timer.preset == .classic)
        #expect(timer.currentSessionID == sessionID)
        #expect(timer.intention == "Current work")
        #expect(recorded.isEmpty)
    }

    @Test func aPathStepChangesNothingWhileASessionIsPaused() {
        let timer = makeTimer()
        timer.start()
        timer.pause()

        timer.prepareForPathStep(workMinutes: 10, title: "One hard problem", journalLocked: false)

        #expect(timer.preset == .classic)
        #expect(timer.intention == nil)
    }

    // MARK: - No close flow

    @Test func aPromptLeftByTheRemovedCloseFlowIsDiscarded() {
        let (defaults, cleanUp) = isolatedDefaults()
        defer { cleanUp() }
        // What the close flow stored: a private intention among others.
        defaults.set(Data(#"{"intention":"Private intention"}"#.utf8), forKey: "focus.pendingFocusNote.v1")

        _ = makeTimer(defaults: defaults)

        #expect(defaults.object(forKey: "focus.pendingFocusNote.v1") == nil)
    }

    private func isolatedDefaults() -> (UserDefaults, () -> Void) {
        let suiteName = "ThinkTests.FocusTimerModel.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
    }

    private func makeTimer(
        center: SpyNotificationCenter? = nil,
        defaults: UserDefaults? = nil,
        clock: TestClock = TestClock()
    ) -> PomodoroTimer {
        PomodoroTimer(
            systemSideEffectsEnabled: false,
            defaults: defaults,
            deviceID: UUID(),
            notificationCenter: center,
            now: { clock.now }
        )
    }
}

@MainActor
private final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 10_000)
}

@MainActor
private final class SpyNotificationCenter: FocusNotificationCenter {
    private(set) var authorizationRequests = 0
    private(set) var pending: [String: TimeInterval] = [:]
    private(set) var addedRequests = 0

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequests += 1
        return true
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        identifiers.forEach { pending.removeValue(forKey: $0) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests += 1
        let trigger = request.trigger as? UNTimeIntervalNotificationTrigger
        pending[request.identifier] = trigger?.timeInterval ?? 0
    }

    var pendingIntervals: [TimeInterval] { pending.values.sorted() }
}
