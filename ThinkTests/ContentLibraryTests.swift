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

    @Test func dailyLineQuestionAndActionRemainPaired() {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))

        for _ in ContentLibrary.practices.indices {
            let practice = ContentLibrary.dailyPractice(for: day)

            #expect(ContentLibrary.dailyQuote(for: day) == practice.quote)
            #expect(ContentLibrary.dailyQuestion(for: day) == practice.question)
            #expect(ContentLibrary.dailyAction(for: day) == practice.action)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
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
        let house = ContentLibrary.quotes.filter { $0.source == nil }
        let attributed = ContentLibrary.quotes.filter { $0.source != nil }

        #expect(!house.isEmpty)
        #expect(house.allSatisfy { $0.attribution == nil })
        #expect(attributed.allSatisfy { $0.attribution == $0.author })
    }

    @Test func everyAttributedLineCarriesReviewableProvenance() {
        let house = ContentLibrary.quotes.filter { $0.source == nil }
        let attributed = ContentLibrary.quotes.filter { $0.source != nil }

        #expect(house.allSatisfy { $0.source == nil })
        #expect(!attributed.isEmpty)
        #expect(attributed.allSatisfy { quote in
            guard let source = quote.source else { return false }
            return !source.work.isEmpty
                && !source.locator.isEmpty
                && !source.edition.isEmpty
                && source.url.hasPrefix("https://")
        })
    }

    @Test func practicesMeetEditorialShape() {
        let whitespace = CharacterSet.whitespacesAndNewlines

        #expect(ContentLibrary.practices.allSatisfy {
            let quoteWordCount = $0.quote.text.split(whereSeparator: \.isWhitespace).count
            return !$0.question.trimmingCharacters(in: whitespace).isEmpty
                && !$0.action.trimmingCharacters(in: whitespace).isEmpty
                && $0.quote.text.count <= 100
                && quoteWordCount <= 20
                && $0.question.count <= 150
                && $0.action.count <= 150
        })
        #expect(Set(ContentLibrary.actions).count == ContentLibrary.actions.count)
    }

    @Test func libraryIsLargeEnoughForQuarterlyRotation() {
        #expect(ContentLibrary.quotes.count >= 90)
        #expect(ContentLibrary.questions.count >= 90)
        #expect(ContentLibrary.actions.count == ContentLibrary.quotes.count)
        #expect(ContentLibrary.practices.count == ContentLibrary.quotes.count)
        #expect(Set(ContentLibrary.questions).count == ContentLibrary.questions.count)
    }
}
