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
        let firstDay = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let secondDay = Calendar.current.date(byAdding: .day, value: 1, to: firstDay)!
        let firstIndex = Int(firstDay.timeIntervalSince1970 / 86_400) % ContentLibrary.quotes.count
        let secondIndex = Int(secondDay.timeIntervalSince1970 / 86_400) % ContentLibrary.quotes.count

        #expect(ContentLibrary.dailyQuote(for: firstDay) == ContentLibrary.quotes[firstIndex])
        #expect(ContentLibrary.dailyQuote(for: secondDay) == ContentLibrary.quotes[secondIndex])
        #expect(secondIndex == (firstIndex + 1) % ContentLibrary.quotes.count)
    }

    @Test func dailyQuestionUsesStableDayRotation() {
        let firstDay = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let secondDay = Calendar.current.date(byAdding: .day, value: 1, to: firstDay)!
        let firstIndex = Int(firstDay.timeIntervalSince1970 / 86_400) % ContentLibrary.questions.count
        let secondIndex = Int(secondDay.timeIntervalSince1970 / 86_400) % ContentLibrary.questions.count

        #expect(ContentLibrary.dailyQuestion(for: firstDay) == ContentLibrary.questions[firstIndex])
        #expect(ContentLibrary.dailyQuestion(for: secondDay) == ContentLibrary.questions[secondIndex])
        #expect(secondIndex == (firstIndex + 1) % ContentLibrary.questions.count)
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
