//
//  SyncCoordinatorProgressTests.swift
//  ThinkTests
//

import Foundation
import Testing
@testable import Think

@MainActor
struct SyncCoordinatorProgressTests {

    @Test func phoneCompletionRunsFocusSideEffectWithExactDuration() {
        let completionDate = Date(timeIntervalSince1970: 19_000)
        let timer = makeTimer("11111111-1111-1111-1111-111111111111", now: completionDate)
        let progress = ProgressStore(defaults: makeDefaults())
        let (transport, _) = MockSyncTransport.paired()
        var sideEffects: [(Date, Int)] = []
        let coordinator = SyncCoordinator(
            role: .phone,
            timer: timer,
            progress: progress,
            ledger: FocusEventLedger(defaults: makeDefaults()),
            transport: transport,
            focusSessionSideEffect: { sideEffects.append(($0, $1)) }
        )
        coordinator.activate()

        timer.select(.init(workMinutes: 25, restMinutes: 5))
        timer.start()
        let completedState = TimerSyncState(
            workMinutes: 25,
            restMinutes: 5,
            phase: PomodoroTimer.Phase.work.rawValue,
            isRunning: true,
            endDate: completionDate,
            remainingSeconds: 0,
            revision: Revision(
                date: completionDate.addingTimeInterval(1),
                deviceID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
            )
        )

        #expect(timer.apply(completedState))
        #expect(sideEffects.count == 1)
        #expect(sideEffects.first?.0 == completionDate)
        #expect(sideEffects.first?.1 == 25)
    }

    @Test func watchOfflineCompletionReachesPhoneAndCanonicalSnapshotReturns() {
        let completionDate = Date(timeIntervalSince1970: 20_000)
        let (phoneTransport, watchTransport) = MockSyncTransport.paired()
        let phoneProgress = ProgressStore(defaults: makeDefaults())
        let watchProgress = ProgressStore(defaults: makeDefaults())
        var reloads = 0
        let phoneTimer = makeTimer("11111111-1111-1111-1111-111111111111", now: completionDate)
        let watchTimer = makeTimer("22222222-2222-2222-2222-222222222222", now: completionDate)
        let phone = SyncCoordinator(
            role: .phone,
            timer: phoneTimer,
            progress: phoneProgress,
            ledger: FocusEventLedger(defaults: makeDefaults()),
            transport: phoneTransport
        )
        let watch = SyncCoordinator(
            role: .watch,
            timer: watchTimer,
            progress: watchProgress,
            ledger: FocusEventLedger(defaults: makeDefaults()),
            transport: watchTransport,
            reloadComplication: { reloads += 1 }
        )
        phone.activate()
        watch.activate()

        watchTimer.select(.init(workMinutes: 0, restMinutes: 5))
        watchTransport.setReachable(false)
        watchTimer.start()
        watchTimer.resync()

        #expect(watchProgress.totalFocusSessions == 1)
        #expect(phoneProgress.totalFocusSessions == 0)
        #expect(watch.ledger.pendingEvents.count == 1)

        watchTransport.setReachable(true)

        #expect(phoneProgress.totalFocusSessions == 1)
        #expect(watchProgress.totalFocusSessions == 1)
        #expect(watch.ledger.pendingEvents.isEmpty)
        #expect(reloads == 2)
        #expect(watchTransport.receivedEnvelopes.contains { $0.progressSnapshot != nil })
    }

    @Test func duplicatePhoneEventIsAppliedOnceAndAcknowledgedBeforePublish() throws {
        let completionDate = Date(timeIntervalSince1970: 21_000)
        let (phoneTransport, watchTransport) = MockSyncTransport.paired()
        let phoneProgress = ProgressStore(defaults: makeDefaults())
        let watchProgress = ProgressStore(defaults: makeDefaults())
        var sideEffects: [(Date, Int)] = []
        let phone = SyncCoordinator(
            role: .phone,
            timer: makeTimer("11111111-1111-1111-1111-111111111111", now: completionDate),
            progress: phoneProgress,
            ledger: FocusEventLedger(defaults: makeDefaults()),
            transport: phoneTransport,
            focusSessionSideEffect: { sideEffects.append(($0, $1)) }
        )
        let watch = makeCoordinator(
            role: .watch,
            timer: makeTimer("22222222-2222-2222-2222-222222222222", now: completionDate),
            progress: watchProgress,
            transport: watchTransport
        )
        phone.activate()
        watch.activate()
        let event = FocusSessionEvent(endDate: completionDate, durationMinutes: 50)
        let eventData = try SyncCodec.encode(event)

        watchTransport.transferUserInfo(SyncTransportPayload(focusSessionEvent: eventData))
        watchTransport.transferUserInfo(SyncTransportPayload(focusSessionEvent: eventData))

        #expect(phoneProgress.totalFocusSessions == 1)
        #expect(phone.ledger.appliedEventIDs == [event.id])
        #expect(sideEffects.count == 1)
        #expect(sideEffects.first?.0 == completionDate)
        #expect(sideEffects.first?.1 == 50)
        let lastPhoneContext = try #require(
            watchTransport.receivedEnvelopes.last(where: { $0.progressSnapshot != nil })?.progressSnapshot
        )
        let snapshot = try SyncCodec.decode(ProgressSnapshot.self, from: lastPhoneContext)
        #expect(snapshot.appliedEventIDs == [event.id])
    }

    @Test func watchOriginatedDurationLandsOnlyInPhoneHistory() {
        var now = Date(timeIntervalSince1970: 23_000)
        let (phoneTransport, watchTransport) = MockSyncTransport.paired()
        let phoneProgress = ProgressStore(defaults: makeDefaults(), now: { now })
        let watchProgress = ProgressStore(defaults: makeDefaults(), now: { now })
        let phoneTimer = makeTimer("11111111-1111-1111-1111-111111111111", now: now)
        let watchTimer = PomodoroTimer(
            systemSideEffectsEnabled: false,
            deviceID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            now: { now }
        )
        let phone = makeCoordinator(
            role: .phone,
            timer: phoneTimer,
            progress: phoneProgress,
            transport: phoneTransport
        )
        let watch = makeCoordinator(
            role: .watch,
            timer: watchTimer,
            progress: watchProgress,
            transport: watchTransport
        )
        phone.activate()
        watch.activate()

        watchTimer.select(.long)
        watchTimer.start()
        now = now.addingTimeInterval(50 * 60)
        watchTimer.resync()

        #expect(phoneProgress.focusHistory.map(\.durationMinutes) == [50])
        #expect(watchProgress.focusHistory.isEmpty)
        #expect(phoneProgress.focusHistory.first?.completedAt == now)
        #expect(phoneProgress.totalFocusSessions == 1)
        #expect(watchProgress.totalFocusSessions == 1)
    }

    @Test func watchSnapshotReplaceThenReplayPreservesUnacknowledgedEvent() throws {
        let (transport, _) = MockSyncTransport.paired()
        let defaults = makeDefaults()
        let ledger = FocusEventLedger(defaults: defaults)
        let completionDate = Date(timeIntervalSince1970: 22_000)
        let event = FocusSessionEvent(endDate: completionDate)
        #expect(ledger.addPending(event))
        let progress = ProgressStore(defaults: makeDefaults())
        var reloads = 0
        let coordinator = SyncCoordinator(
            role: .watch,
            timer: makeTimer("22222222-2222-2222-2222-222222222222", now: completionDate),
            progress: progress,
            ledger: ledger,
            transport: transport,
            reloadComplication: { reloads += 1 }
        )
        coordinator.activate()

        let snapshot = ProgressSnapshot(
            streak: 0,
            lastCompletedDay: nil,
            completedDays: [],
            pathCompletedDays: 0,
            lastPathCompletionDay: nil,
            totalFocusSessions: 0,
            focusSessionDay: nil,
            focusSessionDayCount: 0,
            lastOpenDay: nil,
            appliedEventIDs: [],
            publishedAt: completionDate.addingTimeInterval(100)
        )
        let envelope = SyncInboundEnvelope(
            payload: SyncTransportPayload(progressSnapshot: try SyncCodec.encode(snapshot))
        )
        coordinator.syncTransport(transport, didReceive: envelope)

        #expect(progress.totalFocusSessions == 1)
        #expect(ledger.pendingEvents.map(\.id) == [event.id])
        #expect(reloads == 1)
    }

    private func makeCoordinator(
        role: SyncCoordinator.Role,
        timer: PomodoroTimer,
        progress: ProgressStore,
        transport: MockSyncTransport
    ) -> SyncCoordinator {
        SyncCoordinator(
            role: role,
            timer: timer,
            progress: progress,
            ledger: FocusEventLedger(defaults: makeDefaults()),
            transport: transport
        )
    }

    private func makeTimer(_ deviceID: String, now: Date) -> PomodoroTimer {
        PomodoroTimer(
            systemSideEffectsEnabled: false,
            deviceID: UUID(uuidString: deviceID)!,
            now: { now }
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ThinkTests.SyncCoordinatorProgress.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
