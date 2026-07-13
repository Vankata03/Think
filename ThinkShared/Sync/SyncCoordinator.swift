//
//  SyncCoordinator.swift
//  Think
//

import Foundation
import Observation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class SyncCoordinator: NSObject, SyncTransportDelegate {
    enum Role: Sendable {
        case phone
        case watch
    }

    let role: Role
    let timer: PomodoroTimer
    let progress: ProgressStore
    let ledger: FocusEventLedger
    let transport: any SyncTransport

    private let reloadComplication: @MainActor () -> Void
    private let completionSideEffect: @MainActor () -> Void
    private let focusSessionSideEffect: @MainActor (Date, Int) -> Void
    private var isActivated = false
    private var latestTimerData: Data?
    private var latestProgressData: Data?
    private var latestAppliedProgressDate = Date.distantPast

    init(
        role: Role,
        timer: PomodoroTimer,
        progress: ProgressStore,
        ledger: FocusEventLedger,
        transport: any SyncTransport,
        reloadComplication: @escaping @MainActor () -> Void = {},
        completionSideEffect: @escaping @MainActor () -> Void = {},
        focusSessionSideEffect: @escaping @MainActor (Date, Int) -> Void = { _, _ in }
    ) {
        self.role = role
        self.timer = timer
        self.progress = progress
        self.ledger = ledger
        self.transport = transport
        self.reloadComplication = reloadComplication
        self.completionSideEffect = completionSideEffect
        self.focusSessionSideEffect = focusSessionSideEffect
        super.init()
    }

    func activate() {
        guard !isActivated else { return }
        isActivated = true

        timer.onStateChange = { [weak self] state in
            self?.publishTimer(state)
        }
        timer.onWorkSessionComplete = { [weak self] endDate in
            self?.handleWorkSessionCompletion(at: endDate)
        }
        progress.onMutation = { [weak self] _ in
            self?.handleProgressMutation()
        }

        transport.setDelegate(self)
        transport.activate()
    }

    func syncTransportDidActivate(_ transport: any SyncTransport) {
        guard isActivated else { return }
        if role == .phone {
            latestTimerData = try? SyncCodec.encode(timer.syncState)
            latestProgressData = try? SyncCodec.encode(
                progress.snapshot(appliedEventIDs: ledger.appliedEventIDs)
            )
            publishApplicationContext()
        } else {
            publishTimer(timer.syncState)
            requeuePendingEvents()
        }
    }

    func syncTransport(_ transport: any SyncTransport, didReceive envelope: SyncInboundEnvelope) {
        guard isActivated else { return }

        if let timerData = envelope.timer,
           let state = try? SyncCodec.decode(TimerSyncState.self, from: timerData) {
            _ = timer.apply(state)
        }

        if role == .phone {
            if let eventData = envelope.focusSessionEvent,
               let event = try? SyncCodec.decode(FocusSessionEvent.self, from: eventData) {
                receiveFocusSessionEvent(event)
            }
        } else if let progressData = envelope.progressSnapshot,
                  let snapshot = try? SyncCodec.decode(ProgressSnapshot.self, from: progressData) {
            applyProgressSnapshot(snapshot)
        }
    }

    private func publishTimer(_ state: TimerSyncState) {
        guard isActivated,
              let data = try? SyncCodec.encode(state) else { return }
        latestTimerData = data
        publishApplicationContext()
    }

    private func handleProgressMutation() {
        guard role == .phone else { return }
        publishProgressSnapshot()
    }

    private func publishProgressSnapshot() {
        guard role == .phone,
              let data = try? SyncCodec.encode(progress.snapshot(appliedEventIDs: ledger.appliedEventIDs)) else { return }
        latestProgressData = data
        publishApplicationContext()
    }

    private func publishApplicationContext() {
        guard isActivated else { return }
        if latestTimerData == nil {
            latestTimerData = try? SyncCodec.encode(timer.syncState)
        }
        let payload = SyncTransportPayload(
            timer: latestTimerData,
            progressSnapshot: role == .phone ? latestProgressData : nil
        )

        guard transport.isAvailable else { return }
        if transport.isReachable {
            transport.sendMessage(payload)
        }
        do {
            try transport.updateApplicationContext(payload)
        } catch {
            log("application context update failed: \(error.localizedDescription)")
        }
    }

    private func handleWorkSessionCompletion(at endDate: Date) {
        let duration = timer.preset.workMinutes > 0 ? timer.preset.workMinutes : nil
        let event = FocusSessionEvent(endDate: endDate, durationMinutes: duration)

        switch role {
        case .phone:
            guard ledger.recordApplied(event.id) else { return }
            progress.recordFocusSession(
                at: event.completedAt,
                durationMinutes: event.durationMinutes,
                eventID: event.id
            )
            completionSideEffect()
            if let durationMinutes = event.durationMinutes {
                focusSessionSideEffect(event.completedAt, durationMinutes)
            }

        case .watch:
            guard ledger.addPending(event) else { return }
            // Keep the watch UI useful while the phone is away. The phone
            // remains the canonical writer and owns duration history.
            progress.recordFocusSession(at: event.completedAt)
            queue(event)
        }
    }

    private func receiveFocusSessionEvent(_ event: FocusSessionEvent) {
        guard role == .phone,
              !event.id.isEmpty,
              FocusSessionEvent.id(for: event.completedAt) == event.id,
              ledger.recordApplied(event.id) else { return }

        // Record the ID before mutating progress so the mutation-triggered
        // snapshot already acknowledges the event.
        progress.recordFocusSession(
            at: event.completedAt,
            durationMinutes: event.durationMinutes,
            eventID: event.id
        )
        if let durationMinutes = event.durationMinutes, durationMinutes > 0 {
            focusSessionSideEffect(event.completedAt, durationMinutes)
        }
    }

    private func applyProgressSnapshot(_ snapshot: ProgressSnapshot) {
        guard role == .watch,
              snapshot.publishedAt > latestAppliedProgressDate else { return }
        latestAppliedProgressDate = snapshot.publishedAt

        progress.apply(snapshot)
        _ = ledger.acknowledgePending(Set(snapshot.appliedEventIDs))

        // Replay watch-local events that the snapshot has not acknowledged.
        // This path intentionally does not send user-info again.
        for event in ledger.pendingEvents {
            progress.recordFocusSession(at: event.completedAt)
        }
        reloadComplication()
    }

    private func queue(_ event: FocusSessionEvent) {
        guard let data = try? SyncCodec.encode(event), transport.isAvailable else { return }
        transport.transferUserInfo(SyncTransportPayload(focusSessionEvent: data))
    }

    private func requeuePendingEvents() {
        guard role == .watch else { return }
        for event in ledger.pendingEvents {
            queue(event)
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[ThinkSync] \(message)")
        #endif
    }
}

#if canImport(WatchConnectivity)
extension SyncCoordinator: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.syncTransportDidActivate(self.transport)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(propertyList: applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receive(propertyList: userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(propertyList: message)
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    private nonisolated func receive(propertyList values: [String: Any]) {
        guard let envelope = SyncInboundEnvelope(propertyList: values) else { return }
        Task { @MainActor [weak self, envelope] in
            guard let self else { return }
            self.syncTransport(self.transport, didReceive: envelope)
        }
    }
}
#endif
