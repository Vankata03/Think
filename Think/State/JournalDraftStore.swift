import Foundation
import Observation

nonisolated struct JournalDraft: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable { case answer, note, retro, focus, weeklyReview }
    struct Context: Codable, Equatable, Sendable {
        var civilDay: CivilDay
        var practiceID: String?
        var promptSnapshot: String?
        var sessionID: String?
        var editingRecordID: UUID?
        var periodKey: String?
        init(civilDay: CivilDay = .today(), practiceID: String? = nil, promptSnapshot: String? = nil,
             sessionID: String? = nil, editingRecordID: UUID? = nil, periodKey: String? = nil) {
            self.civilDay = civilDay; self.practiceID = practiceID; self.promptSnapshot = promptSnapshot
            self.sessionID = sessionID; self.editingRecordID = editingRecordID; self.periodKey = periodKey
        }
    }
    let id: UUID
    let kind: Kind
    let context: Context
    var text: String = ""
    var fields: [String: String] = [:]
    var mood: String?
    var energy: String?
    var outcome: String?
    var tomorrowIntention: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), kind: Kind, context: Context = Context(), now: Date = .now) {
        self.id = id; self.kind = kind; self.context = context; self.createdAt = now; self.updatedAt = now
    }
    var containsPrivateContent: Bool {
        !text.isEmpty || fields.values.contains { !$0.isEmpty } || mood != nil || energy != nil
        || outcome != nil || tomorrowIntention != nil || context.editingRecordID != nil
        || context.sessionID != nil
    }
}

/// Recovery is a read: callers must authenticate before showing nonblank drafts.
/// The store never silently discards a malformed or unreadable file.
@MainActor @Observable
final class JournalDraftStore {
    enum StoreError: Error { case unavailable, readFailed, writeFailed, deleteFailed, invalidData }
    let directory: URL
    private(set) var revision = 0
    private let fileManager: FileManager

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = directory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrivateJournalDrafts", isDirectory: true)
    }

    func save(_ draft: JournalDraft) throws {
        do {
            try prepareDirectory()
            var value = draft
            value.updatedAt = .now
            let data = try JSONEncoder().encode(value)
            #if os(iOS)
            try data.write(to: url(draft.id), options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: url(draft.id), options: .atomic)
            #endif
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url(draft.id).path)
            revision += 1
        } catch { throw StoreError.writeFailed }
    }

    func draft(id: UUID) throws -> JournalDraft? {
        let location = url(id)
        guard fileManager.fileExists(atPath: location.path) else { return nil }
        let data: Data
        do { data = try Data(contentsOf: location) } catch { throw StoreError.readFailed }
        guard let draft = try? JSONDecoder().decode(JournalDraft.self, from: data), draft.id == id else {
            throw StoreError.invalidData
        }
        return draft
    }

    /// Every readable draft plus the files that could not be decoded. One
    /// corrupt or foreign `.json` never hides the healthy drafts beside it,
    /// and the unreadable files stay on disk untouched for a later build.
    struct Listing {
        var drafts: [JournalDraft] = []
        var unreadableFiles: [URL] = []
        var unreadableCount: Int { unreadableFiles.count }
    }

    /// Only the directory read itself throws; per-file decode failures are
    /// reported in `unreadableFiles` so callers can warn without blocking.
    func listing(kind: JournalDraft.Kind? = nil) throws -> Listing {
        guard fileManager.fileExists(atPath: directory.path) else { return Listing() }
        let urls: [URL]
        do { urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) }
        catch { throw StoreError.readFailed }
        var result = Listing()
        for location in urls where location.pathExtension == "json" {
            guard let id = UUID(uuidString: location.deletingPathExtension().lastPathComponent),
                  let value = try? draft(id: id) else { result.unreadableFiles.append(location); continue }
            if kind == nil || value.kind == kind { result.drafts.append(value) }
        }
        result.drafts.sort {
            $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt
        }
        result.unreadableFiles.sort { $0.lastPathComponent < $1.lastPathComponent }
        return result
    }

    /// Readable drafts only. Use `listing(kind:)` when the caller must
    /// surface unreadable files.
    func drafts(kind: JournalDraft.Kind? = nil) throws -> [JournalDraft] {
        try listing(kind: kind).drafts
    }

    func answerDraft(practiceID: String, day: CivilDay) throws -> JournalDraft? {
        try drafts(kind: .answer).first { $0.context.practiceID == practiceID && $0.context.civilDay.key == day.key }
    }
    func retroDraft(day: CivilDay) throws -> JournalDraft? {
        try drafts(kind: .retro).first { $0.context.civilDay.key == day.key }
    }
    func recoverableDrafts(excluding id: UUID? = nil) throws -> [JournalDraft] {
        try recoverableListing(excluding: id).drafts
    }
    func recoverableListing(excluding id: UUID? = nil) throws -> Listing {
        var result = try listing()
        result.drafts = result.drafts.filter { $0.id != id && $0.containsPrivateContent }
        return result
    }
    func delete(id: UUID) throws {
        guard fileManager.fileExists(atPath: url(id).path) else { return }
        do { try fileManager.removeItem(at: url(id)); revision += 1 }
        catch { throw StoreError.deleteFailed }
    }
    func deleteAll() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        do { try fileManager.removeItem(at: directory); revision += 1 }
        catch { throw StoreError.deleteFailed }
    }
    private func url(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString).appendingPathExtension("json") }
    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        var location = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try location.setResourceValues(values)
        #if os(iOS)
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        #endif
    }
}
