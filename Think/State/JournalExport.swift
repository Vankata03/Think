//
//  JournalExport.swift
//  Think
//

import Foundation

struct JournalExport {
    struct Entry {
        let date: Date
        let prompt: String
        let text: String
        let kind: String
        let mood: Mood?
    }

    struct Retrospective {
        let date: Date
        let wentWell: String
        let improve: String
        let tomorrow: String
        let mood: Mood?
    }

    let exportedAt: Date
    let entries: [Entry]
    let retrospectives: [Retrospective]

    init(entries: [JournalEntry], retrospectives: [DailyRetro], exportedAt: Date = .now) {
        self.exportedAt = exportedAt
        self.entries = entries.map {
            Entry(
                date: $0.date,
                prompt: $0.prompt,
                text: $0.text,
                kind: $0.kind,
                mood: Mood(stored: $0.mood)
            )
        }
        self.retrospectives = retrospectives.map {
            Retrospective(
                date: $0.date,
                wentWell: $0.wentWell,
                improve: $0.improve,
                tomorrow: $0.tomorrow,
                mood: Mood(stored: $0.mood)
            )
        }
    }

    func text(
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        var sections = [
            "Think Journal\nExported: \(dateFormatter.string(from: exportedAt))",
            journalEntriesText(dateFormatter: dateFormatter),
            retrospectivesText(dateFormatter: dateFormatter),
        ]

        sections.append("End of export")
        return sections.joined(separator: "\n\n========================================\n\n") + "\n"
    }

    func writeToTemporaryFile(fileManager: FileManager = .default, now: Date = .now) throws -> URL {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        let filename = "Think-Journal-\(formatter.string(from: now)).txt"
        let url = fileManager.temporaryDirectory.appendingPathComponent(filename)
        try Data(text().utf8).write(to: url, options: .atomic)
        return url
    }

    private func journalEntriesText(dateFormatter: DateFormatter) -> String {
        var blocks = ["JOURNAL ENTRIES"]
        let sortedEntries = entries.sorted { $0.date > $1.date }

        guard !sortedEntries.isEmpty else {
            blocks.append("No journal entries.")
            return blocks.joined(separator: "\n\n")
        }

        blocks.append(contentsOf: sortedEntries.map { entry in
            var lines = [dateFormatter.string(from: entry.date)]
            if let mood = entry.mood {
                lines.append("Mood: \(mood.exportLabel)")
            }
            if entry.kind == JournalEntry.kindQuestion {
                if !entry.prompt.isEmpty {
                    lines.append("Prompt: \(entry.prompt)")
                }
                lines.append("Response:\n\(entry.text)")
            } else if entry.kind == JournalEntry.kindFocus {
                if !entry.prompt.isEmpty {
                    lines.append("Intention: \(entry.prompt)")
                }
                lines.append("After the session:\n\(entry.text)")
            } else {
                lines.append("Note:\n\(entry.text)")
            }
            return lines.joined(separator: "\n")
        })

        return blocks.joined(separator: "\n\n----------------------------------------\n\n")
    }

    private func retrospectivesText(dateFormatter: DateFormatter) -> String {
        var blocks = ["EVENING RETROSPECTIVES"]
        let sortedRetrospectives = retrospectives.sorted { $0.date > $1.date }

        guard !sortedRetrospectives.isEmpty else {
            blocks.append("No evening retrospectives.")
            return blocks.joined(separator: "\n\n")
        }

        blocks.append(contentsOf: sortedRetrospectives.map { retrospective in
            var lines = [dateFormatter.string(from: retrospective.date)]
            if let mood = retrospective.mood {
                lines.append("Mood: \(mood.exportLabel)")
            }
            lines.append(contentsOf: [
                "What went well:\n\(retrospective.wentWell)",
                "What could improve:\n\(retrospective.improve)",
                "Tomorrow:\n\(retrospective.tomorrow)",
            ])
            return lines.joined(separator: "\n\n")
        })

        return blocks.joined(separator: "\n\n----------------------------------------\n\n")
    }
}
