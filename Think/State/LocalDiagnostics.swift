import Foundation
import Observation
import OSLog

/// Deliberately cannot accept arbitrary labels or error descriptions.
@MainActor @Observable
final class LocalDiagnostics {
    enum Event: String { case save, fetch, draftWrite, export, identityMigration }
    enum ErrorCategory: String { case storage, permission, unavailable, unknown }
    struct Sample {
        let event: Event
        let category: ErrorCategory?
        let duration: TimeInterval
    }
    private(set) var samples: [Sample] = []
    private let logger = Logger(subsystem: "com.ivanterziev.Think", category: "JournalOperations")

    func record(_ event: Event, category: ErrorCategory? = nil, duration: TimeInterval = 0) {
        samples.append(Sample(event: event, category: category, duration: max(0, duration)))
        if samples.count > 100 { samples.removeFirst(samples.count - 100) }
        logger.debug("Journal operation \(event.rawValue, privacy: .public), category \(category?.rawValue ?? "none", privacy: .public)")
    }

    static func category(for error: any Error) -> ErrorCategory {
        let code = (error as NSError).code
        if (error as NSError).domain == NSCocoaErrorDomain {
            if code == NSFileWriteNoPermissionError || code == NSFileReadNoPermissionError { return .permission }
            return .storage
        }
        return .unknown
    }
}
