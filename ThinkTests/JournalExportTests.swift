//
//  JournalExportTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct JournalExportTests {

    @Test func exportCreatesReadablePlainText() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-07-04T08:00:00Z"))
        let entry = JournalEntry(
            date: date,
            prompt: "What matters?",
            text: "Make space for the important thing.",
            kind: JournalEntry.kindQuestion
        )
        let note = JournalEntry(
            date: date.addingTimeInterval(60),
            prompt: "",
            text: "Remember this moment.",
            kind: JournalEntry.kindNote
        )
        let retro = DailyRetro(
            date: date,
            wentWell: "Focused work.",
            improve: "Less context switching.",
            tomorrow: "Start with the hard task."
        )

        let export = JournalExport(entries: [entry, note], retrospectives: [retro], exportedAt: date)
        let text = export.text(
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: try #require(TimeZone(secondsFromGMT: 0))
        )

        #expect(text.contains("Think Journal"))
        #expect(text.contains("JOURNAL ENTRIES"))
        #expect(text.contains("Prompt: What matters?"))
        #expect(text.contains("Response:\nMake space for the important thing."))
        #expect(text.contains("Note:\nRemember this moment."))
        #expect(text.contains("EVENING RETROSPECTIVES"))
        #expect(text.contains("What went well:\nFocused work."))
        #expect(text.contains("What could improve:\nLess context switching."))
        #expect(text.contains("Tomorrow:\nStart with the hard task."))
        #expect(!text.contains("\"formatVersion\""))
    }

    @Test func exportExplainsEmptySections() {
        let export = JournalExport(entries: [], retrospectives: [])
        let text = export.text()

        #expect(text.contains("No journal entries."))
        #expect(text.contains("No evening retrospectives."))
    }

    @Test func exportWritesStableDateNamedTextFile() throws {
        let export = JournalExport(entries: [], retrospectives: [])
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-04T08:00:00Z"))

        let url = try export.writeToTemporaryFile(now: now)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.lastPathComponent == "Think-Journal-2026-07-04.txt")
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try String(contentsOf: url, encoding: .utf8).contains("Think Journal"))
    }
}
