//
//  ContentLibraryTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct ContentLibraryTests {

    @Test func dailyQuoteUsesStableDayRotation() {
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!

        let first = ContentLibrary.dailyQuote(for: firstDay)
        let firstIndex = ContentLibrary.quotes.firstIndex(of: first)!

        // Same day is stable; the next day advances exactly one slot.
        #expect(ContentLibrary.dailyQuote(for: firstDay.addingTimeInterval(3_600)) == first)
        #expect(ContentLibrary.dailyQuote(for: secondDay) == ContentLibrary.quotes[(firstIndex + 1) % ContentLibrary.quotes.count])
    }

    @Test func dailyQuestionUsesStableDayRotation() {
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!

        let first = ContentLibrary.dailyQuestion(for: firstDay)
        let firstIndex = ContentLibrary.questions.firstIndex(of: first)!

        #expect(ContentLibrary.dailyQuestion(for: firstDay.addingTimeInterval(3_600)) == first)
        #expect(ContentLibrary.dailyQuestion(for: secondDay) == ContentLibrary.questions[(firstIndex + 1) % ContentLibrary.questions.count])
    }

    @Test func rotationAdvancesOncePerDayAcrossAYear() {
        // Calendar-based day ordinals must advance exactly one slot per
        // local day, including across DST transitions.
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        var previousIndex = ContentLibrary.quotes.firstIndex(of: ContentLibrary.dailyQuote(for: day))!

        for _ in 0..<365 {
            day = calendar.date(byAdding: .day, value: 1, to: day)!
            let index = ContentLibrary.quotes.firstIndex(of: ContentLibrary.dailyQuote(for: day))!
            #expect(index == (previousIndex + 1) % ContentLibrary.quotes.count)
            previousIndex = index
        }
    }

    @Test func quotesHaveStableUniqueIdentifiers() {
        let ids = Set(ContentLibrary.quotes.map(\.id))

        #expect(ids.count == ContentLibrary.quotes.count)
        #expect(ContentLibrary.quotes.allSatisfy { !$0.text.isEmpty && !$0.author.isEmpty })
    }

    @Test func houseLinesCarryNoDisplayAttribution() {
        let house = ContentLibrary.quotes.filter { $0.author == ContentLibrary.houseAuthor }
        let attributed = ContentLibrary.quotes.filter { $0.author != ContentLibrary.houseAuthor }

        #expect(!house.isEmpty)
        #expect(house.allSatisfy { $0.attribution == nil })
        #expect(attributed.allSatisfy { $0.attribution == $0.author })
    }

    @Test func libraryIsLargeEnoughForQuarterlyRotation() {
        #expect(ContentLibrary.quotes.count >= 90)
        #expect(ContentLibrary.questions.count >= 90)
        #expect(Set(ContentLibrary.questions).count == ContentLibrary.questions.count)
    }
}
