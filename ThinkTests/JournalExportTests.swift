//
//  JournalExportTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct JournalExportTests {

    @Test func exportPreservesJournalEntriesAndRetrospectives() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-07-04T08:00:00Z"))
        let entry = JournalEntry(
            date: date,
            prompt: "What matters?",
            text: "Make space for the important thing.",
            kind: JournalEntry.kindQuestion
        )
        let retro = DailyRetro(
            date: date,
            wentWell: "Focused work.",
            improve: "Less context switching.",
            tomorrow: "Start with the hard task."
        )

        let export = JournalExport(entries: [entry], retrospectives: [retro], exportedAt: date)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(JournalExport.self, from: export.encoded())

        #expect(decoded.formatVersion == 1)
        #expect(decoded.exportedAt == date)
        #expect(decoded.entries.count == 1)
        #expect(decoded.entries.first?.prompt == entry.prompt)
        #expect(decoded.entries.first?.text == entry.text)
        #expect(decoded.entries.first?.kind == JournalEntry.kindQuestion)
        #expect(decoded.retrospectives.first?.wentWell == retro.wentWell)
        #expect(decoded.retrospectives.first?.tomorrow == retro.tomorrow)
    }

    @Test func exportWritesStableDateNamedTemporaryFile() throws {
        let export = JournalExport(entries: [], retrospectives: [])
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-04T08:00:00Z"))

        let url = try export.writeToTemporaryFile(now: now)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.lastPathComponent == "Think-Journal-2026-07-04.json")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
