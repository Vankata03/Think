import Foundation
import SwiftData
import Testing
@testable import Think

/// Synthetic simulator comparison, run alone when collecting timings.
/// Reports counts and duration only; never journal text or search terms.
@MainActor struct JournalQueryMeasurementTests {
    @Test func compareLegacyReadsWithRepositoryAtRepresentativeSizes() throws {
        for count in [1_000, 10_000] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let config = ModelConfiguration(schema: JournalDataStore.schema,
                url: directory.appendingPathComponent("measurement.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: JournalDataStore.schema, configurations: config)
            let writer = ModelContext(container)
            writer.autosaveEnabled = false
            let day = CivilDay.today()
            for index in 0..<count {
                let value = JournalEntry(date: day.start.addingTimeInterval(-Double(index) * 86_400),
                    prompt: "Synthetic prompt", text: "Synthetic entry", kind: JournalEntry.kindQuestion)
                value.recordID = UUID()
                writer.insert(value)
            }
            try writer.save()
            var legacyDay: [Double] = [], repositoryDay: [Double] = []
            var legacyPage: [Double] = [], repositoryPage: [Double] = []
            for round in 0..<4 {
                let reader = ModelContext(container)
                let repository = JournalRepository(modelContext: reader)
                let all = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                func oldDay() throws { try withExtendedLifetime(reader) {
                    let rows = try reader.fetch(all)
                    #expect(rows.first { $0.date >= day.start && $0.date < day.next.start } != nil)
                } }
                func newDay() throws { #expect(try repository.answer(for: day) != nil) }
                func oldPage() throws { try withExtendedLifetime(reader) {
                    let rows = try reader.fetch(all)
                    #expect(rows.prefix(30).count == 30)
                } }
                func newPage() throws {
                    let page = try repository.entries(page: .init(offset: 0, limit: 30))
                    #expect(page.records.count == 30 && page.totalCount == count)
                }
                if round.isMultiple(of: 2) {
                    legacyDay.append(try elapsed(oldDay)); repositoryDay.append(try elapsed(newDay))
                    legacyPage.append(try elapsed(oldPage)); repositoryPage.append(try elapsed(newPage))
                } else {
                    repositoryPage.append(try elapsed(newPage)); legacyPage.append(try elapsed(oldPage))
                    repositoryDay.append(try elapsed(newDay)); legacyDay.append(try elapsed(oldDay))
                }
            }
            func mean(_ values: [Double]) -> String { String(format: "%.3f", values.reduce(0, +) / Double(values.count)) }
            print("JOURNAL_MEASUREMENT rows=\(count) samples=4 legacyDayMs=\(mean(legacyDay)) repositoryDayMs=\(mean(repositoryDay)) legacyPageMs=\(mean(legacyPage)) repositoryPageMs=\(mean(repositoryPage))")
        }
    }

    private func elapsed(_ operation: () throws -> Void) rethrows -> Double {
        let start = Date.timeIntervalSinceReferenceDate
        try operation()
        return (Date.timeIntervalSinceReferenceDate - start) * 1_000
    }
}
