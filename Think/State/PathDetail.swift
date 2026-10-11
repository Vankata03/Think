//
//  PathDetail.swift
//  Think
//
//  What path detail shows at a moment (design/paths.md sections 5 and 6):
//  the step card or its done rows, the finished and locked states, the
//  full trail, and what each step's page holds. The views draw it; the
//  rules live here so they can be tested without a screen.
//

import Foundation

@MainActor
struct PathDetail {
    enum Status: Equatable {
        /// A step is open: the step card (section 5.1).
        case open(step: Int)
        /// No step is open; `step` was the last one done and the next opens
        /// at 06:00, tomorrow when `step` was done today (section 5.2).
        case done(step: Int, opensTomorrow: Bool, canUndo: Bool)
        /// The run is finished (section 5.4); `lastOn` is nil when undated.
        case finished(times: Int, lastOn: Date?)
        /// Waits for the path before it (section 5.4).
        case locked(previous: ThinkingPath)
    }

    enum StepState: Equatable {
        /// Done; nil for a step carried over without a date.
        case done(on: Date?)
        case today
        /// The step after one done, waiting for 06:00.
        case opensNext(tomorrow: Bool)
        case later
    }

    struct Step: Equatable, Identifiable {
        let number: Int
        let title: String
        let state: StepState
        var id: Int { number }

        /// "Step n, title" for VoiceOver (paths.md section 3).
        var accessibilityLabel: String {
            String(
                localized: "Step \(number), \(title)",
                comment: "Path detail: a step on the trail for VoiceOver, its number and title.")
        }
    }

    /// What a step's page holds (section 6).
    enum Page: Equatable {
        /// Lesson and task, read only, plus "Completed date" when dated.
        case done(on: Date?)
        /// Lesson and task, read only; the action lives on path detail.
        case today
        /// Locked: "Opens tomorrow at 06:00." (or today, before 06:00).
        case opensNext(tomorrow: Bool)
        /// Locked: "Opens after step n − 1."
        case opensAfter(step: Int)
    }

    let path: ThinkingPath
    let status: Status
    /// Every step of the active run, in order, for the full trail.
    let steps: [Step]
    /// The moment the detail was built for; the next step opens at 06:00.
    let now: Date
    let calendar: Calendar

    init(path: ThinkingPath, progress: ProgressStore, now: Date = .now, calendar: Calendar = .current) {
        self.path = path
        self.now = now
        self.calendar = calendar
        let run = progress.activeRun(for: path.id)
        let done = run?.completedSteps ?? 0
        let isOpen = progress.canCompletePathStep(pathID: path.id, totalSteps: path.steps.count, at: now)

        let status: Status
        if !progress.isPathUnlocked(path.id), let previous = progress.prerequisite(for: path.id) {
            status = .locked(previous: previous)
        } else if run?.isComplete == true {
            status = .finished(
                times: progress.finishedRunCount(for: path.id), lastOn: progress.lastFinishedRunDate(for: path.id))
        } else if isOpen {
            status = .open(step: done + 1)
        } else {
            let last = run?.lastCompletionDate ?? progress.lastPathCompletionDay
            let doneToday = last.map { calendar.isDate($0, inSameDayAs: now) } ?? true
            status = .done(
                step: done, opensTomorrow: doneToday, canUndo: progress.canUndoPathStep(pathID: path.id, at: now))
        }
        self.status = status

        let dates = Dictionary((run?.completions ?? []).map { ($0.step, $0.date) }, uniquingKeysWith: { $1 })
        steps = path.steps.enumerated().map { index, step in
            let number = index + 1
            let state: StepState =
                if number <= done {
                    .done(on: dates[number])
                } else if number == done + 1 {
                    switch status {
                    case .open: .today
                    case .done(_, let tomorrow, _): .opensNext(tomorrow: tomorrow)
                    case .finished, .locked: .later
                    }
                } else {
                    .later
                }
            return Step(number: number, title: step.title, state: state)
        }
    }

    /// 06:00 in the locale's time format.
    func openingTime(locale: Locale = .current) -> String {
        PathsList.openingTime(now: now, calendar: calendar, locale: locale)
    }

    /// "Opens tomorrow at 06:00" for the next row, or "Opens today at 06:00" before 06:00.
    func opening(tomorrow: Bool, locale: Locale = .current) -> String {
        PathsList.opening(tomorrow: tomorrow, now: now, calendar: calendar, locale: locale)
    }

    /// A disc's state for VoiceOver (paths.md section 3).
    func accessibilityValue(of step: Step, locale: Locale = .current) -> String {
        switch step.state {
        case .done:
            String(localized: "done", comment: "Path detail: VoiceOver value of a step that is done.")
        case .today:
            String(localized: "today", comment: "Path detail: VoiceOver value of the step open today.")
        case .opensNext(true):
            String(
                localized: "opens tomorrow at \(openingTime(locale: locale))",
                comment: "Path detail: VoiceOver value of the next step. The argument is 06:00 in the locale's time format.")
        case .opensNext(false):
            String(
                localized: "opens today at \(openingTime(locale: locale))",
                comment: "Path detail: VoiceOver value of the next step before 06:00. The argument is 06:00 in the locale's time format.")
        case .later:
            String(localized: "not open yet", comment: "Path detail: VoiceOver value of a step not open yet.")
        }
    }

    func page(for number: Int) -> Page {
        guard steps.indices.contains(number - 1) else { return .opensAfter(step: number - 1) }
        return switch steps[number - 1].state {
        case .done(let date): .done(on: date)
        case .today: .today
        case .opensNext(let tomorrow): .opensNext(tomorrow: tomorrow)
        case .later: .opensAfter(step: number - 1)
        }
    }
}
