//
//  TodayRitualTests.swift
//  ThinkTests
//

import Testing

@testable import Think

/// Walks one day through the ritual as Today shows it (today.md sections 2
/// and 3): the next-act panel, the arc markers and the acts section.
@MainActor
struct TodayRitualTests {
    @Test func aFreshMorningOffersTheQuestion() {
        let ritual = TodayRitual(answered: false, moveDone: false, retroWritten: false, hour: 9)

        #expect(ritual.panel == .act(.question))
        #expect(ritual.arcStates == .init(question: .next, move: .later, retro: .later))
        #expect(ritual.otherActs == [.move, .retro])
    }

    @Test func anAnsweredQuestionRotatesThePanelToTheMove() {
        let ritual = TodayRitual(answered: true, moveDone: false, retroWritten: false, hour: 10.5)

        #expect(ritual.panel == .act(.move))
        #expect(ritual.arcStates == .init(question: .done, move: .next, retro: .later))
        #expect(ritual.otherActs == [.question, .retro])
    }

    /// Before 20:00 the retro is only the later row and the dashed marker.
    @Test func beforeEightTheRetroWaitsAsALaterAct() {
        let ritual = TodayRitual(answered: true, moveDone: true, retroWritten: false, hour: 19.98)

        #expect(ritual.panel == .complete)
        #expect(ritual.arcStates == .init(question: .done, move: .done, retro: .later))
        #expect(ritual.otherActs == [.question, .move, .retro])
    }

    @Test func atEightTheRetroBecomesTheNextAct() {
        let ritual = TodayRitual(answered: true, moveDone: true, retroWritten: false, hour: 20)

        #expect(ritual.panel == .act(.retro))
        #expect(ritual.arcStates == .init(question: .done, move: .done, retro: .next))
        #expect(ritual.otherActs == [.question, .move])
    }

    @Test func aWrittenRetroCompletesThePractice() {
        let ritual = TodayRitual(answered: true, moveDone: true, retroWritten: true, hour: 21.25)

        #expect(ritual.panel == .complete)
        #expect(ritual.isComplete)
        #expect(ritual.arcStates == .init(question: .done, move: .done, retro: .done))
        #expect(ritual.arcStates.doneCount == 3)
        #expect(ritual.otherActs == [.question, .move, .retro])
    }

    /// Only one marker is ever "next": an evening with the question still
    /// open keeps the retro later.
    @Test func anOpenQuestionInTheEveningKeepsTheRetroLater() {
        let ritual = TodayRitual(answered: false, moveDone: false, retroWritten: false, hour: 21)

        #expect(ritual.panel == .act(.question))
        #expect(ritual.arcStates == .init(question: .next, move: .later, retro: .later))
    }

    @Test func undoingTheMoveInTheEveningRestoresTheMovePanel() {
        var ritual = TodayRitual(answered: true, moveDone: true, retroWritten: false, hour: 20.5)
        #expect(ritual.panel == .act(.retro))

        ritual.moveDone = false

        #expect(ritual.panel == .act(.move))
        #expect(ritual.arcStates == .init(question: .done, move: .next, retro: .later))
        #expect(ritual.otherActs == [.question, .retro])
    }

    @Test func practiceIsCompleteOnlyWithAllThreeActs() {
        #expect(!TodayRitual(answered: true, moveDone: true, retroWritten: false, hour: 15).isComplete)
        #expect(TodayRitual(answered: true, moveDone: true, retroWritten: true, hour: 15).isComplete)
    }
}
