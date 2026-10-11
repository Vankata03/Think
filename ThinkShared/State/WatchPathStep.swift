//
//  WatchPathStep.swift
//  ThinkShared
//
//  Deep focus's next step as the Watch's Today shows it, read-only
//  (design/paths.md section 9). It follows the phone's 06:00 opening rule
//  through `ProgressStore`, so both devices agree on whether a step is open.
//

import Foundation

@MainActor
struct WatchPathStep: Equatable {
    /// The step's number in the run, "Step n".
    let number: Int
    let step: PathStep
    /// Nil while the step is open; otherwise 06:00 on the day it opens.
    let opensAt: Date?
    /// "Opens tomorrow" rather than "Opens today", before 06:00 on the opening day.
    let opensTomorrow: Bool

    /// Nil once the run is finished.
    init?(
        progress: ProgressStore, path: ThinkingPath = PathLibrary.deepFocus,
        now: Date = .now, calendar: Calendar = .current
    ) {
        let done = progress.activeRun(for: path.id)?.completedSteps ?? 0
        guard let step = path.currentStep(afterCompleted: done) else { return nil }
        number = done + 1
        self.step = step
        let isOpen = progress.canCompletePathStep(pathID: path.id, totalSteps: path.steps.count, at: now)
        opensAt = isOpen ? nil : progress.nextPathStepOpening(pathID: path.id)
        opensTomorrow = opensAt.map { !calendar.isDate($0, inSameDayAs: now) } ?? false
    }
}
