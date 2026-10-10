//
//  PathsListTests.swift
//  ThinkTests
//
//  What the Paths list shows (design/paths.md section 4): which step the
//  hero carries, and how each available path's row reads.
//

import Foundation
import Testing
@testable import Think

@MainActor
struct PathsListTests {

    @Test func aFreshStartShowsDeepFocusStepOneInTheHero() {
        let store = makeStore()

        let list = PathsList(progress: store, now: time(day: 0, hour: 9), calendar: utcCalendar)

        #expect(list.hero?.path.id == deepFocus)
        #expect(list.hero?.form == .open(step: 1))
    }

    @Test func aStepDoneTodayTurnsTheHeroToItsDoneForm() {
        let store = makeStore()
        #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: 0, hour: 9)))
        #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: 1, hour: 9)))

        let list = PathsList(progress: store, now: time(day: 1, hour: 20), calendar: utcCalendar)

        #expect(list.hero?.path.id == deepFocus)
        #expect(list.hero?.form == .done(step: 2, opensTomorrow: true))
    }

    @Test func withTwoOpenStepsTheHeroShowsThePathPractisedMostRecently() {
        let store = makeStore()
        finishDeepFocus(store)
        #expect(store.startNewRun(pathID: deepFocus, totalSteps: 21, at: time(day: 21, hour: 8)) != nil)
        #expect(store.completePathStep(pathID: clearThinking, totalSteps: 7, at: time(day: 22, hour: 9)))

        let list = PathsList(progress: store, now: time(day: 23, hour: 10), calendar: utcCalendar)

        #expect(list.hero?.path.id == clearThinking)
        #expect(list.hero?.form == .open(step: 2))
    }

    @Test func finishingDeepFocusPutsClearThinkingStepOneInTheHero() {
        let store = makeStore()
        finishDeepFocus(store)

        let list = PathsList(progress: store, now: time(day: 21, hour: 10), calendar: utcCalendar)

        #expect(list.hero?.path.id == clearThinking)
        #expect(list.hero?.form == .open(step: 1))
    }

    @Test func aRepeatJustBegunOutranksAPathNeverStarted() {
        let store = makeStore()
        finishDeepFocus(store)
        #expect(store.startNewRun(pathID: deepFocus, totalSteps: 21, at: time(day: 21, hour: 8)) != nil)

        let list = PathsList(progress: store, now: time(day: 21, hour: 10), calendar: utcCalendar)

        #expect(list.hero?.path.id == deepFocus)
        #expect(list.hero?.form == .open(step: 1))
    }

    @Test func whenEveryPathIsFinishedThereIsNoHero() {
        let store = makeStore()
        finishDeepFocus(store)
        for day in 21..<28 {
            #expect(store.completePathStep(pathID: clearThinking, totalSteps: 7, at: time(day: day, hour: 9)))
        }

        let list = PathsList(progress: store, now: time(day: 28, hour: 10), calendar: utcCalendar)

        #expect(list.hero == nil)
    }

    @Test func aStepWaitingBeforeSixOpensTodayNotTomorrow() {
        let store = makeStore()
        #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: 0, hour: 23)))

        let list = PathsList(progress: store, now: time(day: 1, hour: 2), calendar: utcCalendar)

        #expect(list.hero?.form == .done(step: 1, opensTomorrow: false))
    }

    @Test func rowsListOnlyAvailablePathsAndCountTheRest() {
        let store = makeStore()
        #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: 0, hour: 9)))

        let list = PathsList(progress: store, now: time(day: 1, hour: 10), calendar: utcCalendar)

        #expect(list.rows.map(\.path.id) == [deepFocus, clearThinking])
        #expect(list.rows.map(\.state) == [
            .inRun(done: 1, total: 21, openStepToday: nil),
            .locked(previous: PathLibrary.deepFocus),
        ])
        #expect(list.pathsInDevelopment == 2)
    }

    @Test func aSecondOpenStepIsNamedOnItsRowAndAFinishedPathShowsItsCount() {
        let store = makeStore()
        finishDeepFocus(store)
        #expect(store.startNewRun(pathID: deepFocus, totalSteps: 21, at: time(day: 21, hour: 8)) != nil)
        #expect(store.completePathStep(pathID: clearThinking, totalSteps: 7, at: time(day: 22, hour: 9)))

        let twoOpen = PathsList(progress: store, now: time(day: 23, hour: 10), calendar: utcCalendar)
        #expect(twoOpen.rows.map(\.state) == [
            .inRun(done: 0, total: 21, openStepToday: 1),
            .inRun(done: 1, total: 7, openStepToday: nil),
        ])

        let finishedStore = makeStore()
        finishDeepFocus(finishedStore)
        let finished = PathsList(progress: finishedStore, now: time(day: 21, hour: 10), calendar: utcCalendar)
        #expect(finished.rows.map(\.state) == [
            .finished(times: 1),
            .inRun(done: 0, total: 7, openStepToday: nil),
        ])
    }

    @Test func theHeroReadsAsOneSentenceInBothForms() {
        let store = makeStore()
        for day in 0..<4 {
            #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: day, hour: 9)))
        }
        let british = Locale(identifier: "en_GB")

        let open = PathsList(progress: store, now: time(day: 4, hour: 8), calendar: utcCalendar)
        #expect(open.hero?.accessibilityLabel(locale: british)
            == "Today on Deep focus, step 5 of 21, Single-tab work, 25 minutes")

        #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: 4, hour: 9)))
        let done = PathsList(progress: store, now: time(day: 4, hour: 10), calendar: utcCalendar)
        #expect(done.hero?.accessibilityLabel(locale: british)
            == "Step 5 done, Boredom training, Opens tomorrow at 06:00")
    }

    // MARK: - Helpers

    private func finishDeepFocus(_ store: ProgressStore) {
        for day in 0..<21 {
            #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: day, hour: 9)))
        }
    }

    private let deepFocus = PathLibrary.deepFocus.id
    private let clearThinking = PathLibrary.clearThinking.id

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// A time on a day counted from 2027-01-15 00:00 UTC.
    private func time(day: Int, hour: Int, minute: Int = 0) -> Date {
        Date(timeIntervalSince1970: 1_799_971_200 + Double(day * 86_400 + hour * 3_600 + minute * 60))
    }

    private func makeStore() -> ProgressStore {
        let suiteName = "ThinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return ProgressStore(defaults: defaults, calendar: utcCalendar, now: { time(day: 0, hour: 9) })
    }
}
