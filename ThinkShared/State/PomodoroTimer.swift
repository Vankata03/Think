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
/// `endDate`, not tick counting — so the timer stays correct across app
/// suspension. A local notification fires at phase end when the app is in
/// the background.
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
        private enum Kind: Hashable {
            case classic
            case long
            case custom
        }

        private let kind: Kind
        let workMinutes: Int
        let restMinutes: Int

        var label: String { "\(workMinutes) / \(restMinutes)" }
        var isCustom: Bool { kind == .custom }

        init(workMinutes: Int, restMinutes: Int) {
            self.workMinutes = workMinutes
            self.restMinutes = restMinutes
            if workMinutes == Self.classic.workMinutes,
               restMinutes == Self.classic.restMinutes {
                kind = .classic
            } else if workMinutes == Self.long.workMinutes,
                      restMinutes == Self.long.restMinutes {
                kind = .long
            } else {
                kind = .custom
            }
        }

        private init(kind: Kind, workMinutes: Int, restMinutes: Int) {
            self.kind = kind
            self.workMinutes = workMinutes
            self.restMinutes = restMinutes
        }

        static let classic = Preset(kind: .classic, workMinutes: 25, restMinutes: 5)
        static let long = Preset(kind: .long, workMinutes: 50, restMinutes: 10)
        static let all: [Preset] = [.classic, .long]
        static let customWorkMinutesRange = 5...120
        static let customRestMinutesRange = 1...30
        static let defaultCustom = Preset(kind: .custom, workMinutes: 30, restMinutes: 5)

        static func custom(workMinutes: Int, restMinutes: Int) -> Preset {
            Preset(kind: .custom, workMinutes: workMinutes, restMinutes: restMinutes)
        }

        static func isValidCustom(workMinutes: Int, restMinutes: Int) -> Bool {
            customWorkMinutesRange.contains(workMinutes)
                && customRestMinutesRange.contains(restMinutes)
        }
    }

    private static let workEndNotificationID = "pomodoro-work-end"
    private static let restEndNotificationID = "pomodoro-rest-end"
    private static let notificationIDs = [workEndNotificationID, restEndNotificationID]
    private static let persistedStateKey = SharedDefaults.pomodoroTimerStateKey
    #if os(iOS)
    // Stored outside `PersistedState` because the intention is phone-only
    // and that struct is decoded on the watch as well.
    private static let intentionKey = "focus.intention"
    private static let lastIntentionKey = "focus.lastIntention"
    private static let lastIntentionDateKey = "focus.lastIntentionDate"
    #endif

    private struct PersistedState: Codable {
        let workMinutes: Int
        let restMinutes: Int
        let isCustomPreset: Bool?
        let phase: String
        let remainingSeconds: Int
        let isRunning: Bool
        let endDate: Date?
        let revision: Revision?

        private enum CodingKeys: String, CodingKey {
            case workMinutes
            case restMinutes
            case isCustomPreset
            case phase
            case remainingSeconds
            case isRunning
            case endDate
            case revision
        }
    }

    private(set) var preset: Preset = .classic
    private(set) var phase: Phase = .work
    private(set) var remainingSeconds: Int = Preset.classic.workMinutes * 60
    private(set) var isRunning = false
    private(set) var currentRevision: Revision
    private(set) var customPreset: Preset
    private(set) var automaticTransitionCount = 0

    #if os(iOS)
    /// One line on what this session is for. Phone-local on purpose: it is
    /// not in `TimerSyncState`, so the watch timer and the sync codec
    /// version stay untouched.
    private(set) var intention: String?

    /// Offered as a one-tap suggestion for the next session of the same
    /// day, so a repeat session costs no typing.
    private(set) var lastIntention: String?
    private var lastIntentionDate: Date?

    /// Set when a work phase completes with an intention, in time for the
    /// app to ask how it went. Nil the rest of the time.
    private(set) var pendingFocusNote: FocusNotePrompt?

    struct FocusNotePrompt: Identifiable, Equatable {
        let id = UUID()
        let intention: String
        let completedAt: Date
    }

    static let intentionMaxLength = 60

    /// A completion noticed later than this is treated as one that
    /// happened while the app was away. A "how did it go?" sheet for a
    /// session that ended hours ago is worse than no sheet at all.
    static let focusNotePromptWindow: TimeInterval = 120

    /// How long an unanswered prompt stays offerable once it exists.
    static let focusNotePromptExpiry: TimeInterval = 15 * 60
    #endif

    /// Called when a work phase runs to completion. The date is the original
    /// work-phase end date, not the newly-created break end date.
    var onWorkSessionComplete: ((Date) -> Void)?

    /// Called after each local semantic mutation. Tick-only updates are silent.
    var onStateChange: ((TimerSyncState) -> Void)?

    private var endDate: Date?
    private var tickTask: Task<Void, Never>?
    #if os(iOS) && canImport(UserNotifications)
    private var notificationScheduleTask: Task<Void, Never>?
    #endif
    private var requestedAuthorization = false
    private var liveActivityID: String?
    private let systemSideEffectsEnabled: Bool
    private let defaults: UserDefaults?
    private let deviceID: UUID
    private let now: () -> Date
    private var applyingRemoteState = false

    init(
        systemSideEffectsEnabled: Bool = true,
        defaults: UserDefaults? = nil,
        deviceID: UUID = SharedDefaults.syncDeviceID(),
        now: @escaping () -> Date = { .now }
    ) {
        let resolvedDefaults = defaults ?? (systemSideEffectsEnabled ? SharedDefaults.appGroup() : nil)
        self.systemSideEffectsEnabled = systemSideEffectsEnabled
        self.defaults = resolvedDefaults
        self.deviceID = deviceID
        self.now = now
        self.currentRevision = Revision(date: .distantPast, deviceID: deviceID)
        self.customPreset = Self.loadCustomPreset(from: resolvedDefaults)
        restorePersistedState()
        #if os(iOS)
        restoreIntentions()
        #endif
    }

    #if os(iOS)
    /// Trims, and treats whitespace-only as absent. An over-long value is
    /// rejected rather than truncated: the composer caps input at
    /// `intentionMaxLength`, so anything longer reached here by mistake.
    static func normalizedIntention(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= intentionMaxLength else { return nil }
        return trimmed
    }

    /// Setting an intention never starts, stops, or reschedules anything —
    /// it annotates the session in flight. Deliberately not cleared by
    /// `reset()` or `skipPhase()`: an interrupted session is usually
    /// restarted on the same task.
    func setIntention(_ raw: String?) {
        intention = Self.normalizedIntention(raw)
        persistIntentions()
        if isRunning, systemSideEffectsEnabled {
            syncLiveActivity()
        }
    }

    /// The previous intention, offered only on the day it was used. A
    /// yesterday suggestion is noise.
    func suggestedIntention(on date: Date = .now, calendar: Calendar = .current) -> String? {
        guard let lastIntention,
              let lastIntentionDate,
              calendar.isDate(lastIntentionDate, inSameDayAs: date) else { return nil }
        return lastIntention
    }

    func clearPendingFocusNote() {
        pendingFocusNote = nil
    }

    /// Drops a prompt nobody came back for. The sheet lives on the Focus
    /// tab, which may not be visited again for hours; asking how a session
    /// went long after it ended is the stale prompt this avoids.
    func discardStalePendingFocusNote(now: Date = .now) {
        guard let pendingFocusNote,
              now.timeIntervalSince(pendingFocusNote.completedAt) > Self.focusNotePromptExpiry
        else { return }
        self.pendingFocusNote = nil
    }

    private func completeIntention(workEndDate: Date, detectedAt: Date) {
        guard let intention else { return }
        lastIntention = intention
        lastIntentionDate = workEndDate
        self.intention = nil
        if detectedAt.timeIntervalSince(workEndDate) <= Self.focusNotePromptWindow {
            pendingFocusNote = FocusNotePrompt(intention: intention, completedAt: workEndDate)
        }
        persistIntentions()
    }

    private func restoreIntentions() {
        guard let defaults else { return }
        intention = Self.normalizedIntention(defaults.string(forKey: Self.intentionKey))
        lastIntention = Self.normalizedIntention(defaults.string(forKey: Self.lastIntentionKey))
        lastIntentionDate = defaults.object(forKey: Self.lastIntentionDateKey) as? Date
    }

    private func persistIntentions() {
        guard let defaults else { return }
        defaults.set(intention, forKey: Self.intentionKey)
        defaults.set(lastIntention, forKey: Self.lastIntentionKey)
        defaults.set(lastIntentionDate, forKey: Self.lastIntentionDateKey)
    }
    #endif

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

    var syncState: TimerSyncState {
        TimerSyncState(
            workMinutes: preset.workMinutes,
            restMinutes: preset.restMinutes,
            isCustomPreset: preset.isCustom,
            phase: phase.rawValue,
            isRunning: isRunning,
            endDate: isRunning ? endDate : nil,
            remainingSeconds: remainingSeconds,
            revision: currentRevision
        )
    }

    func select(_ preset: Preset) {
        stopRunningWithoutPublishing()
        self.preset = preset
        adoptCustomPresetIfNeeded(preset)
        phase = .work
        remainingSeconds = preset.workMinutes * 60
        finishLocalMutation()
    }

    @discardableResult
    func selectCustom(workMinutes: Int, restMinutes: Int) -> Bool {
        guard Preset.isValidCustom(
            workMinutes: workMinutes,
            restMinutes: restMinutes
        ) else { return false }

        select(.custom(workMinutes: workMinutes, restMinutes: restMinutes))
        return true
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        if systemSideEffectsEnabled {
            requestAuthorizationIfNeeded()
        }
        beginRunning()
        finishLocalMutation()
    }

    private func beginRunning() {
        isRunning = true
        endDate = now().addingTimeInterval(TimeInterval(remainingSeconds))
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
        guard isRunning else { return }
        if let endDate {
            remainingSeconds = max(0, Int(endDate.timeIntervalSince(now()).rounded(.up)))
        }
        stopRunningWithoutPublishing()
        finishLocalMutation()
    }

    func reset() {
        stopRunningWithoutPublishing()
        phase = .work
        remainingSeconds = preset.workMinutes * 60
        finishLocalMutation()
    }

    func skipPhase() {
        let wasRunning = isRunning
        stopRunningWithoutPublishing()

        // Skipping never counts the session.
        if phase == .work {
            phase = .rest
            remainingSeconds = phaseTotalSeconds
        } else {
            phase = .work
            remainingSeconds = phaseTotalSeconds
        }

        if wasRunning {
            beginRunning()
        }
        finishLocalMutation()
    }

    /// Re-derives state from the wall clock. Runs every tick while active,
    /// and should also be called when the app returns to the foreground so a
    /// suspended timer catches up immediately.
    func resync() {
        guard isRunning, let endDate else { return }
        let currentDate = now()
        let remaining = Int(endDate.timeIntervalSince(currentDate).rounded(.up))
        if remaining > 0 {
            remainingSeconds = remaining
            return
        }

        if phase == .work {
            onWorkSessionComplete?(endDate)
            #if os(iOS)
            completeIntention(workEndDate: endDate, detectedAt: currentDate)
            #endif
            phase = .rest
            automaticTransitionCount += 1
            let restEnd = endDate.addingTimeInterval(TimeInterval(preset.restMinutes * 60))
            if restEnd > currentDate {
                self.endDate = restEnd
                remainingSeconds = Int(restEnd.timeIntervalSince(currentDate).rounded(.up))
                if systemSideEffectsEnabled {
                    schedulePhaseEndNotification()
                    syncLiveActivity(alertsTransition: true)
                }
                finishLocalMutation()
                return
            }
            // Work and break both elapsed while suspended.
        }

        // Break finished: stop at the start of a fresh work phase.
        stopRunningWithoutPublishing()
        phase = .work
        remainingSeconds = preset.workMinutes * 60
        automaticTransitionCount += 1
        finishLocalMutation()
    }

    /// Applies a newer remote state without publishing it back. Local side
    /// effects are rebuilt from the adopted wall-clock state.
    @discardableResult
    func apply(_ remote: TimerSyncState) -> Bool {
        guard remote.revision > currentRevision,
              isValid(remote) else { return false }

        applyingRemoteState = true
        defer { applyingRemoteState = false }

        stopRunningWithoutPublishing()
        applyResolvedPreset(
            workMinutes: remote.workMinutes,
            restMinutes: remote.restMinutes,
            isCustom: remote.isCustomPreset
        )
        phase = Phase(rawValue: remote.phase)!
        currentRevision = remote.revision
        remainingSeconds = remote.remainingSeconds

        if remote.isRunning, let remoteEndDate = remote.endDate {
            if systemSideEffectsEnabled {
                requestAuthorizationIfNeeded()
            }
            isRunning = true
            endDate = remoteEndDate
            remainingSeconds = max(0, Int(remoteEndDate.timeIntervalSince(now()).rounded(.up)))
            if remoteEndDate > now() {
                if systemSideEffectsEnabled {
                    schedulePhaseEndNotification()
                    syncLiveActivity()
                }
                startTicking()
                persistState()
            } else {
                // Catch up locally, but suppress the echo publication. The
                // completion callback still attributes a finished work phase.
                resync()
            }
        } else {
            persistState()
        }

        return true
    }

    private func isValid(_ remote: TimerSyncState) -> Bool {
        guard remote.workMinutes >= 0,
              remote.restMinutes >= 0,
              Phase(rawValue: remote.phase) != nil,
              remote.remainingSeconds >= 0 else { return false }

        if remote.isRunning {
            return remote.endDate != nil
        }
        return remote.endDate == nil
    }

    private func stopRunningWithoutPublishing() {
        isRunning = false
        endDate = nil
        tickTask?.cancel()
        tickTask = nil
        if systemSideEffectsEnabled {
            #if os(iOS) && canImport(UserNotifications)
            replacePhaseEndNotifications(with: [])
            #endif
            endLiveActivity()
        }
    }

    private func finishLocalMutation() {
        if !applyingRemoteState {
            let candidateDate = now()
            let nextDate = max(candidateDate, currentRevision.date.addingTimeInterval(0.001))
            currentRevision = Revision(date: nextDate, deviceID: deviceID)
        }
        persistState()
        if !applyingRemoteState {
            onStateChange?(syncState)
        }
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

        applyResolvedPreset(
            workMinutes: state.workMinutes,
            restMinutes: state.restMinutes,
            isCustom: state.isCustomPreset
        )
        phase = restoredPhase
        remainingSeconds = max(0, state.remainingSeconds)
        if let revision = state.revision {
            currentRevision = revision
        }

        guard state.isRunning, let restoredEndDate = state.endDate else { return }

        isRunning = true
        endDate = restoredEndDate
        remainingSeconds = max(0, Int(restoredEndDate.timeIntervalSince(now()).rounded(.up)))
        startTicking()

        if systemSideEffectsEnabled, restoredEndDate > now() {
            // ActivityKit keeps the activity alive across app termination, but
            // the in-memory ID does not survive. Reconnect before creating a
            // new activity.
            syncLiveActivity()
        }
    }

    private func applyResolvedPreset(
        workMinutes: Int,
        restMinutes: Int,
        isCustom: Bool?
    ) {
        preset = resolvedPreset(
            workMinutes: workMinutes,
            restMinutes: restMinutes,
            isCustom: isCustom
        )
        adoptCustomPresetIfNeeded(preset)
    }

    private func persistState() {
        guard let defaults else { return }
        let state = PersistedState(
            workMinutes: preset.workMinutes,
            restMinutes: preset.restMinutes,
            isCustomPreset: preset.isCustom,
            phase: phase.rawValue,
            remainingSeconds: remainingSeconds,
            isRunning: isRunning,
            endDate: isRunning ? endDate : nil,
            revision: currentRevision
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.persistedStateKey)
    }

    private static func loadCustomPreset(from defaults: UserDefaults?) -> Preset {
        guard let defaults,
              defaults.object(forKey: SharedDefaults.pomodoroCustomWorkMinutesKey) != nil,
              defaults.object(forKey: SharedDefaults.pomodoroCustomRestMinutesKey) != nil else {
            return .defaultCustom
        }

        let workMinutes = defaults.integer(forKey: SharedDefaults.pomodoroCustomWorkMinutesKey)
        let restMinutes = defaults.integer(forKey: SharedDefaults.pomodoroCustomRestMinutesKey)
        guard Preset.isValidCustom(
            workMinutes: workMinutes,
            restMinutes: restMinutes
        ) else { return .defaultCustom }

        return .custom(workMinutes: workMinutes, restMinutes: restMinutes)
    }

    private func resolvedPreset(
        workMinutes: Int,
        restMinutes: Int,
        isCustom: Bool?
    ) -> Preset {
        if isCustom == true,
           Preset.isValidCustom(workMinutes: workMinutes, restMinutes: restMinutes) {
            return .custom(workMinutes: workMinutes, restMinutes: restMinutes)
        }
        return Preset(workMinutes: workMinutes, restMinutes: restMinutes)
    }

    private func adoptCustomPresetIfNeeded(_ preset: Preset) {
        guard preset.isCustom,
              Preset.isValidCustom(
                workMinutes: preset.workMinutes,
                restMinutes: preset.restMinutes
              ) else { return }

        customPreset = preset
        defaults?.set(
            preset.workMinutes,
            forKey: SharedDefaults.pomodoroCustomWorkMinutesKey
        )
        defaults?.set(
            preset.restMinutes,
            forKey: SharedDefaults.pomodoroCustomRestMinutesKey
        )
    }

    private func syncLiveActivity(alertsTransition: Bool = false) {
        #if os(iOS) && canImport(ActivityKit)
        guard let endDate else { return }
        let startDate = endDate.addingTimeInterval(-TimeInterval(max(phaseTotalSeconds, 1)))
        let state = PomodoroActivityAttributes.ContentState(
            phase: phase == .work ? .work : .rest,
            startDate: startDate,
            endDate: endDate,
            restEndDate: phase == .work
                ? endDate.addingTimeInterval(TimeInterval(preset.restMinutes * 60))
                : nil,
            // A break is not the work it was for; the intention rides
            // along with the work phase only.
            intention: phase == .work ? intention : nil
        )
        let content = ActivityContent(state: state, staleDate: endDate)
        let alertConfiguration = alertsTransition
            ? AlertConfiguration(
                title: "Break",
                body: "Nice work. Time for a break.",
                sound: .default
            )
            : nil
        let existingActivity = Activity<PomodoroActivityAttributes>.activities.first { activity in
            activity.id == liveActivityID
        } ?? Activity<PomodoroActivityAttributes>.activities.first

        if let existingActivity {
            // ActivityKit keeps the activity alive across app termination, but
            // the in-memory ID does not survive. Reconnect before creating a
            // new activity.
            liveActivityID = existingActivity.id
            let id = existingActivity.id
            Task.detached {
                await Activity<PomodoroActivityAttributes>.activities
                    .first { $0.id == id }?
                    .update(content, alertConfiguration: alertConfiguration)
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
        #if os(iOS) && canImport(UserNotifications)
        guard let endDate else { return }
        let requests: [UNNotificationRequest]
        switch phase {
        case .work:
            requests = [
                notificationRequest(
                    id: Self.workEndNotificationID,
                    title: String(localized: "Session complete"),
                    body: String(localized: "Nice work. Time for a break."),
                    date: endDate
                ),
                notificationRequest(
                    id: Self.restEndNotificationID,
                    title: String(localized: "Break over"),
                    body: String(localized: "Ready for the next session?"),
                    date: endDate.addingTimeInterval(TimeInterval(preset.restMinutes * 60))
                )
            ].compactMap { $0 }
        case .rest:
            requests = [notificationRequest(
                id: Self.restEndNotificationID,
                title: String(localized: "Break over"),
                body: String(localized: "Ready for the next session?"),
                date: endDate
            )].compactMap { $0 }
        }
        replacePhaseEndNotifications(with: requests)
        #endif
    }

    #if os(iOS) && canImport(UserNotifications)
    private func notificationRequest(
        id: String,
        title: String,
        body: String,
        date: Date
    ) -> UNNotificationRequest? {
        let interval = date.timeIntervalSince(now())
        guard interval > 1 else { return nil }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private func replacePhaseEndNotifications(with requests: [UNNotificationRequest]) {
        let previousTask = notificationScheduleTask
        previousTask?.cancel()

        // Serialize removal and registration. A replacement waits for any
        // in-flight add before removing stale requests and installing its own.
        notificationScheduleTask = Task {
            await previousTask?.value
            guard !Task.isCancelled else { return }

            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: Self.notificationIDs)
            for request in requests {
                guard !Task.isCancelled else { return }
                try? await center.add(request)
            }
        }
    }
    #endif
}
