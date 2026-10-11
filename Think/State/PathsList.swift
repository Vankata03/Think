//
//  PathsList.swift
//  Think
//
//  What the Paths list shows at a moment (design/paths.md section 4): the
//  hero's step and one row per available path. The view draws it; the rules
//  live here so they can be tested without a screen.
//

import Foundation

@MainActor
struct PathsList {
    struct Hero: Equatable {
        enum Form: Equatable {
            /// Today's step is open.
            case open(step: Int)
            /// No step is open; `step` was the last one done. The next opens
            /// at 06:00, tomorrow when `step` was done today.
            case done(step: Int, opensTomorrow: Bool)
        }

        let path: ThinkingPath
        let form: Form
        /// Steps done in the active run, for the trail window.
        let doneSteps: Int
        /// The day the hero was built for; the next step opens at 06:00.
        let now: Date
        let calendar: Calendar

        /// The step the hero names: today's, or in the done form the next one.
        var step: PathStep? {
            let number =
                switch form {
                case .open(let step): step
                case .done(let step, _): step + 1
                }
            return path.steps.indices.contains(number - 1) ? path.steps[number - 1] : nil
        }

        var window: StepTrailWindowLayout {
            let today: Int? = if case .open(let step) = form { step } else { nil }
            return StepTrailWindowLayout(totalSteps: path.steps.count, doneSteps: doneSteps, todayStep: today)
        }

        /// "Opens tomorrow at 06:00" in the locale's time format (paths.md section 7).
        func opening(locale: Locale = .current) -> String {
            guard case .done(_, let tomorrow) = form else { return "" }
            return PathsList.opening(tomorrow: tomorrow, now: now, calendar: calendar, locale: locale)
        }

        /// The hero is one VoiceOver element (paths.md section 4.1).
        func accessibilityLabel(locale: Locale = .current) -> String {
            let title = step?.title ?? ""
            switch form {
            case .open(let number):
                let minutes = step?.estimatedMinutes ?? 0
                return [
                    String(
                        localized: "Today on \(path.name), step \(number) of \(path.steps.count)",
                        comment: "Paths hero for VoiceOver: path name, step number and run length."),
                    title,
                    String(localized: "\(minutes) minutes", comment: "Paths hero for VoiceOver: the step's time."),
                ].joined(separator: ", ")
            case .done(let number, _):
                return [
                    String(localized: "Step \(number) done", comment: "Paths hero after today's step is done."),
                    title,
                    opening(locale: locale),
                ].joined(separator: ", ")
            }
        }
    }

    struct Row: Equatable, Identifiable {
        enum State: Equatable {
            /// In a run, or unlocked and not started. `openStepToday` names
            /// an open step the hero does not show.
            case inRun(done: Int, total: Int, openStepToday: Int?)
            /// Finished, no new run begun.
            case finished(times: Int)
            /// Waits for the path before it.
            case locked(previous: ThinkingPath)
        }

        let path: ThinkingPath
        let state: State
        var id: String { path.id }
    }

    let hero: Hero?
    /// One row per available path, in library order.
    let rows: [Row]
    /// Paths that are not available yet; they have no rows, only the footer.
    let pathsInDevelopment: Int

    init(
        progress: ProgressStore, library: [ThinkingPath] = PathLibrary.all,
        now: Date = .now, calendar: Calendar = .current
    ) {
        let available = library.filter(\.isAvailable)
        let isOpen = Dictionary(
            uniqueKeysWithValues: available.map { path in
                (path.id, progress.canCompletePathStep(pathID: path.id, totalSteps: path.steps.count, at: now))
            })
        let inRun = Self.ranked(available, by: progress).filter { path in
            progress.isPathUnlocked(path.id) && progress.activeRun(for: path.id)?.isComplete != true
        }

        let hero: Hero?
        if let path = inRun.first(where: { isOpen[$0.id] == true }) {
            let done = Self.doneSteps(path, progress)
            hero = Hero(path: path, form: .open(step: done + 1), doneSteps: done, now: now, calendar: calendar)
        } else if let path = inRun.first {
            let done = Self.doneSteps(path, progress)
            let last = progress.activeRun(for: path.id)?.lastCompletionDate ?? progress.lastPathCompletionDay
            let doneToday = last.map { calendar.isDate($0, inSameDayAs: now) } ?? true
            hero = Hero(
                path: path, form: .done(step: done, opensTomorrow: doneToday), doneSteps: done,
                now: now, calendar: calendar)
        } else {
            hero = nil
        }
        self.hero = hero

        rows = available.map { path in
            let run = progress.activeRun(for: path.id)
            if !progress.isPathUnlocked(path.id), let previous = progress.prerequisite(for: path.id) {
                return Row(path: path, state: .locked(previous: previous))
            }
            if run?.isComplete == true {
                return Row(path: path, state: .finished(times: progress.finishedRunCount(for: path.id)))
            }
            let done = run?.completedSteps ?? 0
            let openToday = isOpen[path.id] == true && hero?.path.id != path.id ? done + 1 : nil
            return Row(path: path, state: .inRun(done: done, total: path.steps.count, openStepToday: openToday))
        }
        pathsInDevelopment = library.count - available.count
    }

    /// "Opens tomorrow at 06:00", or "Opens today at 06:00" before 06:00 (paths.md section 7).
    static func opening(tomorrow: Bool, now: Date, calendar: Calendar, locale: Locale) -> String {
        let time = openingTime(now: now, calendar: calendar, locale: locale)
        return tomorrow
            ? String(localized: "Opens tomorrow at \(time)", comment: "Paths: when the next step opens.")
            : String(
                localized: "Opens today at \(time)",
                comment: "Paths: when the next step opens, before 06:00 on the day it opens.")
    }

    /// 06:00, when the next step opens, in the locale's own hour pattern:
    /// "06:00" in 24-hour locales, "6:00 AM" in 12-hour ones.
    static func openingTime(now: Date, calendar: Calendar, locale: Locale) -> String {
        let six = calendar.date(bySettingHour: ProgressStore.nextStepOpeningHour, minute: 0, second: 0, of: calendar.startOfDay(for: now))!
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: six)
    }

    /// Most recently practised first; a path with no date ranks last, and a
    /// tie keeps library order (paths.md section 4.1).
    private static func ranked(_ paths: [ThinkingPath], by progress: ProgressStore) -> [ThinkingPath] {
        let dates = paths.map { progress.lastPractisedDate(for: $0.id) }
        return paths.indices.sorted { a, b in
            switch (dates[a], dates[b]) {
            case (let x?, let y?) where x != y: x > y
            case (_?, nil): true
            case (nil, _?): false
            default: a < b
            }
        }
        .map { paths[$0] }
    }

    private static func doneSteps(_ path: ThinkingPath, _ progress: ProgressStore) -> Int {
        progress.activeRun(for: path.id)?.completedSteps ?? 0
    }
}
