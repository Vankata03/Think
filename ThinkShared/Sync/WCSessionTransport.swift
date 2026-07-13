//
//  WCSessionTransport.swift
//  Think
//

#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

@MainActor
final class WCSessionTransport: NSObject, SyncTransport, WCSessionDelegate {
    private let session: WCSession
    private weak var delegate: (any SyncTransportDelegate)?

    init(session: WCSession = .default) {
        self.session = session
        super.init()
    }

    var isAvailable: Bool {
        #if os(iOS)
        WCSession.isSupported() && session.isPaired && session.isWatchAppInstalled
        #else
        WCSession.isSupported()
        #endif
    }

    var isReachable: Bool {
        isAvailable && session.isReachable
    }

    func setDelegate(_ delegate: (any SyncTransportDelegate)?) {
        self.delegate = delegate
        if let sessionDelegate = delegate as? WCSessionDelegate {
            session.delegate = sessionDelegate
        } else {
            session.delegate = self
        }
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.activate()
    }

    func sendMessage(_ payload: SyncTransportPayload) {
        guard isAvailable, session.isReachable else { return }
        session.sendMessage(payload.propertyList, replyHandler: nil) { error in
            #if DEBUG
            print("[ThinkSync] message send failed: \(error.localizedDescription)")
            #endif
        }
    }

    func updateApplicationContext(_ payload: SyncTransportPayload) throws {
        guard isAvailable else { return }
        try session.updateApplicationContext(payload.propertyList)
    }

    func transferUserInfo(_ payload: SyncTransportPayload) {
        guard isAvailable else { return }
        session.transferUserInfo(payload.propertyList)
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard error == nil, activationState == .activated else { return }
        Task { @MainActor [weak self] in
            guard let self, let delegate = self.delegate else { return }
            delegate.syncTransportDidActivate(self)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        deliver(userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        deliver(message)
    }

    private nonisolated func deliver(_ values: [String: Any]) {
        guard let envelope = SyncInboundEnvelope(propertyList: values) else { return }
        Task { @MainActor [weak self, envelope] in
            guard let self, let delegate = self.delegate else { return }
            delegate.syncTransport(self, didReceive: envelope)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#else
import Foundation

@MainActor
final class WCSessionTransport: NoopSyncTransport { }
#endif
