//
//  FocusNotificationCenter.swift
//  Think
//

import UserNotifications

/// The part of the notification centre the focus timer touches, so tests
/// can stand in a spy. Authorization is listed only so a test can prove
/// the timer never asks: permission belongs to onboarding and Settings.
@MainActor
protocol FocusNotificationCenter: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

@MainActor
final class SystemFocusNotificationCenter: FocusNotificationCenter {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
}
