//
//  SessionEndAlertsTests.swift
//  ThinkTests
//

import Foundation
import Testing
import UserNotifications

@testable import Think

/// The Settings switch for Session end alerts (`progress-settings.md`
/// section 3): it drives the timer's phase-end notifications and asks for
/// notification permission only when it has never been asked.
@MainActor
struct SessionEndAlertsTests {

    @Test func turningAlertsOnAsksForPermissionWhenItWasNeverAsked() async {
        let permission = SpyNotificationPermission(status: .notDetermined, grants: true)
        let timer = makeTimer()
        timer.setSessionEndAlertsEnabled(false)

        let status = await SessionEndAlerts.setEnabled(true, timer: timer, permission: permission)

        #expect(permission.requests == 1)
        #expect(timer.sessionEndAlertsEnabled)
        #expect(status == .authorized)
    }

    @Test(arguments: [UNAuthorizationStatus.authorized, .denied, .provisional])
    func turningAlertsOnNeverAsksAgainOnceAnswered(status: UNAuthorizationStatus) async {
        let permission = SpyNotificationPermission(status: status)
        let timer = makeTimer()
        timer.setSessionEndAlertsEnabled(false)

        let result = await SessionEndAlerts.setEnabled(true, timer: timer, permission: permission)

        #expect(permission.requests == 0)
        #expect(timer.sessionEndAlertsEnabled)
        #expect(result == status)
    }

    @Test func turningAlertsOffNeverAsks() async {
        let permission = SpyNotificationPermission(status: .notDetermined)
        let timer = makeTimer()

        let result = await SessionEndAlerts.setEnabled(false, timer: timer, permission: permission)

        #expect(permission.requests == 0)
        #expect(!timer.sessionEndAlertsEnabled)
        #expect(result == .notDetermined)
    }

    @Test func aRefusedAskStillLeavesTheSwitchOnAndReportsDenied() async {
        let permission = SpyNotificationPermission(status: .notDetermined, grants: false)
        let timer = makeTimer()
        timer.setSessionEndAlertsEnabled(false)

        let result = await SessionEndAlerts.setEnabled(true, timer: timer, permission: permission)

        #expect(timer.sessionEndAlertsEnabled)
        #expect(result == .denied)
    }

    @Test func theSwitchTurnsTheRunningSessionsPhaseEndNotificationsOffAndOn() async {
        let center = SpyFocusNotificationCenter()
        let permission = SpyNotificationPermission(status: .authorized)
        let timer = makeTimer(center: center)
        timer.start()
        await timer.settleNotificationScheduling()
        #expect(center.pendingIntervals == [25 * 60, 30 * 60])

        _ = await SessionEndAlerts.setEnabled(false, timer: timer, permission: permission)
        await timer.settleNotificationScheduling()
        #expect(center.pendingIntervals.isEmpty)

        _ = await SessionEndAlerts.setEnabled(true, timer: timer, permission: permission)
        await timer.settleNotificationScheduling()
        #expect(center.pendingIntervals == [25 * 60, 30 * 60])
        #expect(center.authorizationRequests == 0)
    }
}

@MainActor
private final class SpyFocusNotificationCenter: FocusNotificationCenter {
    private(set) var authorizationRequests = 0
    private var pending: [String: TimeInterval] = [:]

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequests += 1
        return true
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for identifier in identifiers { pending.removeValue(forKey: identifier) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        let trigger = request.trigger as? UNTimeIntervalNotificationTrigger
        pending[request.identifier] = trigger?.timeInterval ?? 0
    }

    var pendingIntervals: [TimeInterval] { pending.values.sorted() }
}

@MainActor
private final class SpyNotificationPermission: NotificationAuthorizing {
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

private let fixedNow = Date(timeIntervalSinceReferenceDate: 10_000)

@MainActor
private func makeTimer(center: (any FocusNotificationCenter)? = nil) -> PomodoroTimer {
    let suiteName = "ThinkTests.SessionEndAlerts.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return PomodoroTimer(
        systemSideEffectsEnabled: false,
        defaults: defaults,
        deviceID: UUID(),
        notificationCenter: center,
        now: { fixedNow }
    )
}
