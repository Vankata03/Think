//
//  DailyQuoteNotifier.swift
//  Think
//

import Foundation
import SwiftUI
import UIKit
import UserNotifications
import CryptoKit
import OSLog

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
    private static let renderVersion = "paper-v1"
    private static let logger = Logger(subsystem: "com.ivanterziev.Think", category: "notification-timing")
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
        content.userInfo["think.renderVersion"] = renderVersion
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
        guard defaults.bool(forKey: enabledKey) else {
            removePendingRequests()
            return
        }
        guard await NotificationPermission.requestAuthorizationIfNeeded() else { return }
        guard generation == refreshGeneration else { return }

        let minutes = defaults.object(forKey: minutesKey) as? Int ?? defaultMinutes
        let scheduledLines = scheduledDailyLines(
            startingAt: .now,
            minutes: minutes,
            calendar: .current
        )
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard generation == refreshGeneration else { return }
        let desiredIDs = Set(scheduledLines.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers:
            pending.map(\.identifier).filter { identifiers.contains($0) && !desiredIDs.contains($0) }
        )

        await schedule(
            scheduledLines,
            existingRequests: pending,
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
        existingRequests: [UNNotificationRequest] = [],
        isCurrent: @MainActor () -> Bool,
        addRequest: @MainActor (UNNotificationRequest) async throws -> Void,
        removeRequests: @MainActor ([String]) -> Void = { _ in },
        richRequestBuilder: (@MainActor (ScheduledDailyLine) async -> PreparedNotificationRequest)? = nil
    ) async {

        let startedAt = ContinuousClock.now
        let existingByID = Dictionary(existingRequests.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
        let changedLines = scheduledLines.filter { line in
            guard let existing = existingByID[line.identifier] else { return true }
            return !matches(existing, scheduledLine: line)
        }
        defer {
            let elapsed = startedAt.duration(to: .now)
            logger.info("notification.reconcile changed=\(changedLines.count, privacy: .public) duration=\(String(describing: elapsed), privacy: .public)")
        }
        // Establish the changed window immediately. Rich versions replace
        // these requests one by one without delaying the text-only fallback.
        for scheduledLine in changedLines {
            let result = await add(
                notificationRequest(for: scheduledLine),
                isCurrent: isCurrent,
                addRequest: addRequest,
                removeRequests: removeRequests
            )
            if result == .stale { return }
        }

        for scheduledLine in changedLines {
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

    /// A matching rich request already belongs to Notification Center. Keep
    /// it intact instead of replacing it with text and rendering again.
    /// Text-only fallbacks remain eligible for a later rich retry.
    static func matches(_ request: UNNotificationRequest, scheduledLine: ScheduledDailyLine) -> Bool {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return false }
        let expected = notificationRequest(for: scheduledLine)
        return request.identifier == expected.identifier
            && trigger.dateComponents == scheduledLine.trigger.dateComponents
            && trigger.repeats == scheduledLine.trigger.repeats
            && request.content.title == expected.content.title
            && request.content.body == expected.content.body
            && request.content.userInfo["think.renderVersion"] as? String == renderVersion
            && !request.content.attachments.isEmpty
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
        let startedAt = ContinuousClock.now
        let cacheKey = SHA256.hash(data: Data(
            "\(renderVersion)|\(Locale.preferredLanguages.joined(separator: ","))|\(quote.text)|\(quote.attribution ?? "")".utf8
        )).map { String(format: "%02x", $0) }.joined()
        let cachedData = await cachedImageData(key: cacheKey)
        let imageData: Data
        if let cachedData {
            imageData = cachedData
        } else {
            let renderer = ImageRenderer(content: QuoteCardView(quote: quote, style: .paper))
            renderer.proposedSize = ProposedViewSize(QuoteCardView.designSize)
            renderer.scale = attachmentRenderScale
            renderer.isOpaque = true

            guard let image = renderer.uiImage,
                  let renderedData = image.jpegData(compressionQuality: attachmentJPEGQuality) else {
                throw AttachmentError.renderingFailed
            }
            imageData = renderedData
            await cacheImageData(imageData, key: cacheKey)
        }
        logger.info("notification.attachment cacheHit=\(cachedData != nil, privacy: .public) duration=\(String(describing: startedAt.duration(to: .now)), privacy: .public)")

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

    private nonisolated static func cachedImageData(key: String) async -> Data? {
        await Task.detached(priority: .utility) {
            guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
            return try? Data(contentsOf: directory.appending(path: "ThinkQuoteCards/\(key).jpg"))
        }.value
    }

    private nonisolated static func cacheImageData(_ data: Data, key: String) async {
        await Task.detached(priority: .utility) {
            let manager = FileManager.default
            guard let root = manager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
            let directory = root.appending(path: "ThinkQuoteCards", directoryHint: .isDirectory)
            do {
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: directory.appending(path: "\(key).jpg"), options: .atomic)
                let files = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
                let oldestFirst = files.sorted {
                    ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                        < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                }
                for file in oldestFirst.prefix(max(0, files.count - 32)) {
                    try? manager.removeItem(at: file)
                }
            } catch {
                // Optional cache failure must never suppress text delivery.
            }
        }.value
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
