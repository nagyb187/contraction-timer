import Foundation
import WatchConnectivity

@MainActor
final class SyncBridge: NSObject, WCSessionDelegate {
    static let shared = SyncBridge()

    var onSnapshot: ((Snapshot) -> Void)?
    var current: (() -> Snapshot)?

    private var started = false

    func start() {
        guard WCSession.isSupported(), !started else { return }
        started = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ snapshot: Snapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let payload = ["snapshot": data]
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let snapshot = self.current?() {
                self.send(snapshot)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        deliver(message)
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated private func deliver(_ payload: [String: Any]) {
        guard let data = payload["snapshot"] as? Data,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        Task { @MainActor in
            self.onSnapshot?(snapshot)
        }
    }
}
