//
//  JournalExport.swift
//  Think
//

import Foundation

struct JournalExport: Codable {
    struct Entry: Codable {
        let date: Date
        let prompt: String
        let text: String
        let kind: String
    }

    struct Retrospective: Codable {
        let date: Date
        let wentWell: String
        let improve: String
        let tomorrow: String
    }

    let formatVersion: Int
    let exportedAt: Date
    let entries: [Entry]
    let retrospectives: [Retrospective]

    init(entries: [JournalEntry], retrospectives: [DailyRetro], exportedAt: Date = .now) {
        formatVersion = 1
        self.exportedAt = exportedAt
        self.entries = entries.map {
            Entry(date: $0.date, prompt: $0.prompt, text: $0.text, kind: $0.kind)
        }
        self.retrospectives = retrospectives.map {
            Retrospective(
                date: $0.date,
                wentWell: $0.wentWell,
                improve: $0.improve,
                tomorrow: $0.tomorrow
            )
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func writeToTemporaryFile(fileManager: FileManager = .default, now: Date = .now) throws -> URL {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        let filename = "Think-Journal-\(formatter.string(from: now)).json"
        let url = fileManager.temporaryDirectory.appendingPathComponent(filename)
        try encoded().write(to: url, options: .atomic)
        return url
    }
}
