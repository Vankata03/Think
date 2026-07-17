//
//  DailyQuoteNotifier.swift
//  Think
//

import Foundation
import SwiftUI
import UIKit
import UserNotifications

/// Schedules the "daily line" notification. Local notifications can't
/// pick content at fire time, so this keeps a sliding window of the
/// next 8 days scheduled individually, refreshed whenever the app
/// becomes active.
@MainActor
enum DailyQuoteNotifier {
    static let enabledKey = "dailyQuoteNotificationEnabled"
    static let minutesKey = "dailyQuoteNotificationMinutes"
    static let defaultMinutes = 8 * 60

    private static let dayCount = 8
    private static let attachmentRenderScale = 0.5
    private static let attachmentJPEGQuality = 0.86
    private static var refreshGeneration = 0
    private static var activeRefreshTask: Task<Void, Never>?
    private static var identifiers: [String] {
        (0..<dayCount).map { "daily-quote-\($0)" }
    }

    struct ScheduledDailyLine {
        let identifier: String
        let quote: Quote
        let trigger: UNCalendarNotificationTrigger
    }

    struct PreparedNotificationRequest {
        let request: UNNotificationRequest
        private let temporaryDirectoryURL: URL?

        init(request: UNNotificationRequest, temporaryDirectoryURL: URL? = nil) {
            self.request = request
            self.temporaryDirectoryURL = temporaryDirectoryURL
        }

        func removeTemporaryFiles(fileManager: FileManager = .default) {
            guard let temporaryDirectoryURL else { return }
            try? fileManager.removeItem(at: temporaryDirectoryURL)
        }
    }

    static func scheduledRequests(
        startingAt now: Date,
        minutes: Int,
        calendar: Calendar
    ) -> [UNNotificationRequest] {
        scheduledDailyLines(startingAt: now, minutes: minutes, calendar: calendar)
            .map { notificationRequest(for: $0) }
    }

    static func scheduledDailyLines(
        startingAt now: Date,
        minutes: Int,
        calendar: Calendar
    ) -> [ScheduledDailyLine] {
        let today = calendar.startOfDay(for: now)
        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fireDate = calendar.date(byAdding: .minute, value: minutes, to: day),
                  fireDate > now else { return nil }

            let quote = ContentLibrary.dailyQuote(for: day, calendar: calendar)
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return ScheduledDailyLine(
                identifier: "daily-quote-\(offset)",
                quote: quote,
                trigger: trigger
            )
        }
    }

    static func notificationRequest(
        for scheduledLine: ScheduledDailyLine,
        attachment: UNNotificationAttachment? = nil
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Today's line")
        content.body = scheduledLine.quote.notificationText
        content.sound = .default
        if let attachment {
            content.attachments = [attachment]
        }

        return UNNotificationRequest(
            identifier: scheduledLine.identifier,
            content: content,
            trigger: scheduledLine.trigger
        )
    }

    static func refreshSchedule() {
        startRefresh()
    }

    static func refreshScheduleAsync() async {
        await startRefresh().value
    }

    @discardableResult
    private static func startRefresh() -> Task<Void, Never> {
        refreshGeneration += 1
        let generation = refreshGeneration
        let previousTask = activeRefreshTask
        let task = Task { @MainActor in
            await previousTask?.value
            guard generation == refreshGeneration else { return }
            await performRefresh(generation: generation)
        }
        activeRefreshTask = task
        return task
    }

    private static func performRefresh(generation: Int) async {
        let defaults = UserDefaults.standard
        removePendingRequests()
        guard defaults.bool(forKey: enabledKey) else { return }
        guard await NotificationPermission.requestAuthorizationIfNeeded() else { return }
        guard generation == refreshGeneration else { return }

        let minutes = defaults.object(forKey: minutesKey) as? Int ?? defaultMinutes
        let scheduledLines = scheduledDailyLines(
            startingAt: .now,
            minutes: minutes,
            calendar: .current
        )
        let center = UNUserNotificationCenter.current()

        await schedule(
            scheduledLines,
            isCurrent: { generation == refreshGeneration },
            addRequest: { request in
                try await center.add(request)
            },
            removeRequests: { requestIdentifiers in
                center.removePendingNotificationRequests(withIdentifiers: requestIdentifiers)
            }
        )
    }

    static func schedule(
        _ scheduledLines: [ScheduledDailyLine],
        isCurrent: @MainActor () -> Bool,
        addRequest: @MainActor (UNNotificationRequest) async throws -> Void,
        removeRequests: @MainActor ([String]) -> Void = { _ in },
        richRequestBuilder: (@MainActor (ScheduledDailyLine) async -> PreparedNotificationRequest)? = nil
    ) async {

        // Establish the complete window immediately. Rich versions replace
        // these requests one by one without delaying the text-only fallback.
        for scheduledLine in scheduledLines {
            let result = await add(
                notificationRequest(for: scheduledLine),
                isCurrent: isCurrent,
                addRequest: addRequest,
                removeRequests: removeRequests
            )
            if result == .stale { return }
        }

        for scheduledLine in scheduledLines {
            guard isCurrent() else { return }
            let preparedRequest: PreparedNotificationRequest
            if let richRequestBuilder {
                preparedRequest = await richRequestBuilder(scheduledLine)
            } else {
                preparedRequest = await prepareRichRequest(for: scheduledLine)
            }
            // Keep app-owned scratch storage until notification-center
            // acceptance; its attachment data store owns the media afterward.
            defer { preparedRequest.removeTemporaryFiles() }

            guard isCurrent() else { return }
            guard !preparedRequest.request.content.attachments.isEmpty else {
                // The initial text-only add may also have failed. Retry the
                // prepared fallback instead of assuming it was accepted.
                let result = await add(
                    preparedRequest.request,
                    isCurrent: isCurrent,
                    addRequest: addRequest,
                    removeRequests: removeRequests
                )
                if result == .stale { return }
                continue
            }
            let richResult = await add(
                preparedRequest.request,
                isCurrent: isCurrent,
                addRequest: addRequest,
                removeRequests: removeRequests
            )
            switch richResult {
            case .added:
                break
            case .stale:
                return
            case .failed:
                // A rejected attachment must not remove the useful reminder.
                let fallbackResult = await add(
                    notificationRequest(for: scheduledLine),
                    isCurrent: isCurrent,
                    addRequest: addRequest,
                    removeRequests: removeRequests
                )
                if fallbackResult == .stale { return }
            }
        }
    }

    private enum AddResult {
        case added
        case failed
        case stale
    }

    private static func add(
        _ request: UNNotificationRequest,
        isCurrent: @MainActor () -> Bool,
        addRequest: @MainActor (UNNotificationRequest) async throws -> Void,
        removeRequests: @MainActor ([String]) -> Void
    ) async -> AddResult {
        guard isCurrent() else { return .stale }
        do {
            try await addRequest(request)
            guard isCurrent() else {
                removeRequests([request.identifier])
                return .stale
            }
            return .added
        } catch {
            guard isCurrent() else {
                removeRequests([request.identifier])
                return .stale
            }
            return .failed
        }
    }

    static func prepareRichRequest(
        for scheduledLine: ScheduledDailyLine,
        attachmentBuilder: ((Quote, String) async throws -> (UNNotificationAttachment, URL))? = nil
    ) async -> PreparedNotificationRequest {
        do {
            let attachment: UNNotificationAttachment
            let temporaryDirectoryURL: URL
            if let attachmentBuilder {
                (attachment, temporaryDirectoryURL) = try await attachmentBuilder(
                    scheduledLine.quote,
                    scheduledLine.identifier
                )
            } else {
                (attachment, temporaryDirectoryURL) = try await renderedAttachment(
                    for: scheduledLine.quote,
                    identifier: scheduledLine.identifier
                )
            }
            return PreparedNotificationRequest(
                request: notificationRequest(for: scheduledLine, attachment: attachment),
                temporaryDirectoryURL: temporaryDirectoryURL
            )
        } catch {
            return PreparedNotificationRequest(request: notificationRequest(for: scheduledLine))
        }
    }

    private static func renderedAttachment(
        for quote: Quote,
        identifier: String
    ) async throws -> (UNNotificationAttachment, URL) {
        let renderer = ImageRenderer(content: QuoteCardView(quote: quote, style: .paper))
        renderer.proposedSize = ProposedViewSize(QuoteCardView.designSize)
        renderer.scale = attachmentRenderScale
        renderer.isOpaque = true

        guard let image = renderer.uiImage,
              let imageData = image.jpegData(compressionQuality: attachmentJPEGQuality) else {
            throw AttachmentError.renderingFailed
        }

        let (fileURL, directoryURL) = try await persistAttachmentData(imageData)
        do {
            let attachment = try UNNotificationAttachment(
                identifier: "\(identifier)-card",
                url: fileURL
            )
            return (attachment, directoryURL)
        } catch {
            try? FileManager.default.removeItem(at: directoryURL)
            throw error
        }
    }

    private nonisolated static func persistAttachmentData(_ data: Data) async throws -> (URL, URL) {
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let directoryURL = fileManager.temporaryDirectory
                .appending(path: "ThinkDailyLineAttachments", directoryHint: .isDirectory)
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            let fileURL = directoryURL.appending(path: "quote-card.jpg", directoryHint: .notDirectory)

            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                try data.write(to: fileURL, options: .atomic)
                return (fileURL, directoryURL)
            } catch {
                try? fileManager.removeItem(at: directoryURL)
                throw error
            }
        }.value
    }

    private enum AttachmentError: Error {
        case renderingFailed
    }

    static func cancelSchedule() {
        refreshGeneration += 1
        let generation = refreshGeneration
        removePendingRequests()
        let previousTask = activeRefreshTask
        let cleanupTask = Task { @MainActor in
            await previousTask?.value
            guard generation == refreshGeneration else { return }
            removePendingRequests()
        }
        activeRefreshTask = cleanupTask
    }

    private static func removePendingRequests() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
