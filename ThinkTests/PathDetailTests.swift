//
//  PathDetailTests.swift
//  ThinkTests
//
//  What path detail and the step page show (design/paths.md sections 5
//  and 6): the step card, the done rows, the finished and locked states,
//  the full trail and each step's page.
//

import Foundation
import Testing

@testable import Think

@MainActor
struct PathDetailTests {

    @Test func aFreshPathOpensOnStepOneWithTheRestNotOpenYet() {
        let store = makeStore()

        let detail = PathDetail(path: PathLibrary.deepFocus, progress: store, now: time(day: 0, hour: 9), calendar: utcCalendar)

        #expect(detail.status == .open(step: 1))
        #expect(detail.steps.count == 21)
        #expect(detail.steps[0].state == .today)
        #expect(detail.steps[1].state == .later)
        #expect(detail.steps[20].state == .later)
    }

    @Test func completingAStepTurnsTheCardIntoTheDoneRowsAndUndoReversesIt() {
        let store = makeStore()
        let completedAt = time(day: 0, hour: 9)
        #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: completedAt))

        let done = PathDetail(path: PathLibrary.deepFocus, progress: store, now: time(day: 0, hour: 10), calendar: utcCalendar)

        #expect(done.status == .done(step: 1, opensTomorrow: true, canUndo: true))
        #expect(done.steps[0].state == .done(on: completedAt))
        #expect(done.steps[1].state == .opensNext(tomorrow: true))
        #expect(done.steps[2].state == .later)

        #expect(store.undoPathStep(pathID: deepFocus, at: time(day: 0, hour: 10)))
        let undone = PathDetail(path: PathLibrary.deepFocus, progress: store, now: time(day: 0, hour: 10), calendar: utcCalendar)

        #expect(undone.status == .open(step: 1))
        #expect(undone.steps[0].state == .today)
    }

    @Test func aStepDoneYesterdayWaitsForSixAndCannotBeUndone() {
        let store = makeStore()
        #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: 0, hour: 23, minute: 30)))

        let early = PathDetail(path: PathLibrary.deepFocus, progress: store, now: time(day: 1, hour: 5, minute: 59), calendar: utcCalendar)
        let six = PathDetail(path: PathLibrary.deepFocus, progress: store, now: time(day: 1, hour: 6), calendar: utcCalendar)

        #expect(early.status == .done(step: 1, opensTomorrow: false, canUndo: false))
        #expect(early.steps[1].state == .opensNext(tomorrow: false))
        #expect(six.status == .open(step: 2))
    }

    @Test func theLastStepShowsTheFinishedStateWithNoUndo() {
        let store = makeStore()
        finishDeepFocus(store)

        let detail = PathDetail(path: PathLibrary.deepFocus, progress: store, now: time(day: 20, hour: 10), calendar: utcCalendar)

        #expect(detail.status == .finished(times: 1, lastOn: time(day: 20, hour: 9)))
        #expect(detail.steps.allSatisfy { if case .done = $0.state { true } else { false } })
        #expect(!store.canUndoPathStep(pathID: deepFocus, at: time(day: 20, hour: 10)))
    }

    @Test func beginAgainOpensStepOneAtOnce() {
        let store = makeStore()
        finishDeepFocus(store)
        let now = time(day: 20, hour: 10)

        #expect(store.startNewRun(pathID: deepFocus, totalSteps: 21, at: now) != nil)
        let detail = PathDetail(path: PathLibrary.deepFocus, progress: store, now: now, calendar: utcCalendar)

        #expect(detail.status == .open(step: 1))
        #expect(detail.steps[0].state == .today)
        #expect(detail.steps[1].state == .later)
    }

    @Test func aLockedPathNamesThePathBeforeIt() {
        let store = makeStore()

        let detail = PathDetail(path: PathLibrary.clearThinking, progress: store, now: time(day: 0, hour: 9), calendar: utcCalendar)

        #expect(detail.status == .locked(previous: PathLibrary.deepFocus))
    }

    @Test func stepPagesShowContentForDoneAndTodayAndWaitForTheRest() {
        let store = makeStore()
        let completedAt = time(day: 0, hour: 9)
        #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: completedAt))
        let fresh = PathDetail(path: PathLibrary.deepFocus, progress: makeStore(), now: completedAt, calendar: utcCalendar)
        let done = PathDetail(path: PathLibrary.deepFocus, progress: store, now: time(day: 0, hour: 10), calendar: utcCalendar)

        #expect(fresh.page(for: 1) == .today)
        #expect(fresh.page(for: 2) == .opensAfter(step: 1))
        #expect(done.page(for: 1) == .done(on: completedAt))
        #expect(done.page(for: 2) == .opensNext(tomorrow: true))
        #expect(done.page(for: 7) == .opensAfter(step: 6))
    }

    @Test func everyDiscIsLabelledWithItsStepAndState() {
        let store = makeStore()
        #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: 0, hour: 9)))
        let british = Locale(identifier: "en_GB")
        let done = PathDetail(path: PathLibrary.deepFocus, progress: store, now: time(day: 0, hour: 10), calendar: utcCalendar)
        let open = PathDetail(path: PathLibrary.deepFocus, progress: store, now: time(day: 1, hour: 10), calendar: utcCalendar)

        #expect(done.steps[0].accessibilityLabel == "Step 1, Notice the pull")
        #expect(done.accessibilityValue(of: done.steps[0], locale: british) == "done")
        #expect(done.accessibilityValue(of: done.steps[1], locale: british) == "opens tomorrow at 06:00")
        #expect(done.accessibilityValue(of: done.steps[2], locale: british) == "not open yet")
        #expect(open.accessibilityValue(of: open.steps[1], locale: british) == "today")
    }

    // MARK: - Helpers

    private let deepFocus = PathLibrary.deepFocus.id
    private let clearThinking = PathLibrary.clearThinking.id

    private func finishDeepFocus(_ store: ProgressStore) {
        for day in 0..<21 {
            #expect(store.completePathStep(pathID: deepFocus, totalSteps: 21, at: time(day: day, hour: 9)))
        }
    }

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
