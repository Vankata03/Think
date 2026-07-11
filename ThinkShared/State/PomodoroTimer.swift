//
//  PomodoroTimer.swift
//  Think
//

#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation
import Observation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Wall-clock based pomodoro: while running, the source of truth is
/// `endDate`, not tick counting — so the timer stays correct across
/// app suspension. A local notification fires at phase end when the
/// app is in the background.
@MainActor
@Observable
final class PomodoroTimer {

    enum Phase: String {
        case work = "deep work"
        case rest = "break"

        var label: String {
            switch self {
            case .work: String(localized: "deep work")
            case .rest: String(localized: "break")
            }
        }
    }

    struct Preset: Hashable {
        let workMinutes: Int
        let restMinutes: Int

        var label: String { "\(workMinutes) / \(restMinutes)" }

        static let classic = Preset(workMinutes: 25, restMinutes: 5)
        static let long = Preset(workMinutes: 50, restMinutes: 10)
        static let all: [Preset] = [.classic, .long]
    }

    private static let notificationID = "pomodoro-phase-end"
    private static let persistedStateKey = SharedDefaults.pomodoroTimerStateKey

    private struct PersistedState: Codable {
        let workMinutes: Int
        let restMinutes: Int
        let phase: String
        let remainingSeconds: Int
        let isRunning: Bool
        let endDate: Date?
    }

    private(set) var preset: Preset = .classic
    private(set) var phase: Phase = .work
    private(set) var remainingSeconds: Int = Preset.classic.workMinutes * 60
    private(set) var isRunning = false

    /// Called when a work phase runs to completion.
    var onWorkSessionComplete: (() -> Void)?

    private var endDate: Date?
    private var tickTask: Task<Void, Never>?
    private var requestedAuthorization = false
    private var liveActivityID: String?
    private let systemSideEffectsEnabled: Bool
    private let defaults: UserDefaults?

    init(systemSideEffectsEnabled: Bool = true, defaults: UserDefaults? = nil) {
        self.systemSideEffectsEnabled = systemSideEffectsEnabled
        self.defaults = defaults ?? (systemSideEffectsEnabled ? SharedDefaults.appGroup() : nil)
        restorePersistedState()
    }

    var phaseTotalSeconds: Int {
        (phase == .work ? preset.workMinutes : preset.restMinutes) * 60
    }

    var progress: Double {
        guard phaseTotalSeconds > 0 else { return 0 }
        return min(max(1 - Double(remainingSeconds) / Double(phaseTotalSeconds), 0), 1)
    }

    var remainingLabel: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    func select(_ preset: Preset) {
        stopRunning()
        self.preset = preset
        phase = .work
        remainingSeconds = preset.workMinutes * 60
        persistState()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        if systemSideEffectsEnabled {
            requestAuthorizationIfNeeded()
        }
        isRunning = true
        endDate = .now.addingTimeInterval(TimeInterval(remainingSeconds))
        persistState()
        if systemSideEffectsEnabled {
            schedulePhaseEndNotification()
            syncLiveActivity()
        }
        startTicking()
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            let clock = ContinuousClock()
            while !Task.isCancelled {
                try? await clock.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.resync()
            }
        }
    }

    func pause() {
        if let end = endDate {
            remainingSeconds = max(0, Int(end.timeIntervalSinceNow.rounded(.up)))
        }
        stopRunning()
    }

    func reset() {
        stopRunning()
        phase = .work
        remainingSeconds = preset.workMinutes * 60
        persistState()
    }

    func skipPhase() {
        let wasRunning = isRunning
        stopRunning()
        // Skipping never counts the session.
        if phase == .work {
            phase = .rest
            remainingSeconds = phaseTotalSeconds
            if wasRunning {
                start()
            } else {
                persistState()
            }
        } else {
            phase = .work
            remainingSeconds = phaseTotalSeconds
            persistState()
        }
    }

    /// Re-derives state from the wall clock. Runs every tick while
    /// active, and should also be called when the app returns to the
    /// foreground so a suspended timer catches up immediately.
    func resync() {
        guard isRunning, let end = endDate else { return }
        let remaining = Int(end.timeIntervalSinceNow.rounded(.up))
        if remaining > 0 {
            remainingSeconds = remaining
            return
        }

        if phase == .work {
            onWorkSessionComplete?()
            phase = .rest
            let restEnd = end.addingTimeInterval(TimeInterval(preset.restMinutes * 60))
            if restEnd > .now {
                endDate = restEnd
                remainingSeconds = Int(restEnd.timeIntervalSinceNow.rounded(.up))
                persistState()
                if systemSideEffectsEnabled {
                    schedulePhaseEndNotification()
                    syncLiveActivity()
                }
                return
            }
            // Work and break both elapsed while suspended.
        }
        // Break finished: stop at the start of a fresh work phase.
        stopRunning()
        phase = .work
        remainingSeconds = preset.workMinutes * 60
        persistState()
    }

    private func stopRunning() {
        isRunning = false
        endDate = nil
        tickTask?.cancel()
        tickTask = nil
        if systemSideEffectsEnabled {
            #if canImport(UserNotifications)
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
            #endif
            endLiveActivity()
        }
        persistState()
    }

    private func restorePersistedState() {
        guard let defaults,
              let data = defaults.data(forKey: Self.persistedStateKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data),
              state.workMinutes >= 0,
              state.restMinutes >= 0,
              let restoredPhase = Phase(rawValue: state.phase) else {
            return
        }

        preset = Preset(workMinutes: state.workMinutes, restMinutes: state.restMinutes)
        phase = restoredPhase
        remainingSeconds = max(0, state.remainingSeconds)

        guard state.isRunning, let restoredEndDate = state.endDate else { return }

        isRunning = true
        endDate = restoredEndDate
        remainingSeconds = max(0, Int(restoredEndDate.timeIntervalSinceNow.rounded(.up)))
        startTicking()

        if systemSideEffectsEnabled, restoredEndDate > .now {
            // ActivityKit keeps the activity alive across app termination, but
            // the in-memory ID does not survive. Reconnect before creating a
            // new activity.
            syncLiveActivity()
        }
    }

    private func persistState() {
        guard let defaults else { return }
        let state = PersistedState(
            workMinutes: preset.workMinutes,
            restMinutes: preset.restMinutes,
            phase: phase.rawValue,
            remainingSeconds: remainingSeconds,
            isRunning: isRunning,
            endDate: isRunning ? endDate : nil
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.persistedStateKey)
    }

    private func syncLiveActivity() {
        #if os(iOS) && canImport(ActivityKit)
        guard let endDate else { return }
        let startDate = endDate.addingTimeInterval(-TimeInterval(max(phaseTotalSeconds, 1)))
        let state = PomodoroActivityAttributes.ContentState(
            phase: phase == .work ? .work : .rest,
            startDate: startDate,
            endDate: endDate
        )
        let content = ActivityContent(state: state, staleDate: endDate)
        if let id = liveActivityID {
            Task.detached {
                await Activity<PomodoroActivityAttributes>.activities
                    .first { $0.id == id }?
                    .update(content)
            }
        } else if let existingActivity = Activity<PomodoroActivityAttributes>.activities.first {
            // ActivityKit keeps the activity alive across app termination, but
            // the in-memory ID does not survive. Reconnect before creating a
            // new activity.
            liveActivityID = existingActivity.id
            let id = existingActivity.id
            Task.detached {
                await Activity<PomodoroActivityAttributes>.activities
                    .first { $0.id == id }?
                    .update(content)
            }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            let activity = try? Activity.request(attributes: PomodoroActivityAttributes(), content: content)
            liveActivityID = activity?.id
        }
        #endif
    }

    private func endLiveActivity() {
        #if os(iOS) && canImport(ActivityKit)
        liveActivityID = nil
        // Ends every activity of this type, which also cleans up any
        // orphans left over from a previous app run.
        Task.detached {
            for activity in Activity<PomodoroActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }

    private func requestAuthorizationIfNeeded() {
        #if canImport(UserNotifications)
        guard !requestedAuthorization else { return }
        requestedAuthorization = true
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
        #endif
    }

    private func schedulePhaseEndNotification() {
        #if os(iOS) && canImport(ActivityKit) && canImport(UserNotifications)
        // The Live Activity already shows the countdown on the lock
        // screen; the notification is only the fallback when the user
        // has Live Activities disabled.
        guard !ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let endDate else { return }
        let interval = endDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        switch phase {
        case .work:
            content.title = String(localized: "Session complete")
            content.body = String(localized: "Nice work. Time for a break.")
        case .rest:
            content.title = String(localized: "Break over")
            content.body = String(localized: "Ready for the next session?")
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
        #endif
    }
}
