import Foundation
import WatchKit

@MainActor
@Observable
final class WatchStore {
    private let rowsKey = "contractions.v1"
    private let languageKey = "language.v1"
    private let updatedKey = "contractions.updatedAt"

    var rows: [Contraction] = []
    var language: String?
    var now = Date()

    private var updatedAt: TimeInterval = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: rowsKey),
           let stored = try? JSONDecoder().decode([Contraction].self, from: data) {
            rows = Timing.sanitize(stored)
        }
        language = UserDefaults.standard.string(forKey: languageKey)
        updatedAt = UserDefaults.standard.double(forKey: updatedKey)
        let bridge = SyncBridge.shared
        bridge.current = { [weak self] in
            self?.makeSnapshot() ?? Snapshot(rows: [], language: nil, updatedAt: 0)
        }
        bridge.onSnapshot = { [weak self] snapshot in
            self?.applyRemote(snapshot)
        }
        bridge.start()
    }

    var copy: Copy { L10n.copy(for: language ?? "en") }

    var open: Contraction? {
        guard let last = rows.last, last.end == nil else { return nil }
        return last
    }

    func setLanguage(_ code: String) {
        language = code
        persist()
    }

    func begin() {
        guard rows.last?.end != nil || rows.isEmpty else { return }
        rows.append(Contraction(start: Date().timeIntervalSince1970, end: nil))
        persist()
        WKInterfaceDevice.current().play(.click)
    }

    func finish() {
        guard let last = rows.last, last.end == nil else { return }
        rows[rows.count - 1].end = max(Date().timeIntervalSince1970, last.start)
        persist()
        WKInterfaceDevice.current().play(.click)
    }

    func gap(_ seconds: TimeInterval) -> String {
        Timing.gap(seconds, language: language)
    }

    func duration(_ row: Contraction) -> TimeInterval {
        Timing.duration(row, now: now)
    }

    func stamp(_ ts: TimeInterval) -> String {
        Timing.stamp(ts, language: language, now: now)
    }

    private func makeSnapshot() -> Snapshot {
        Snapshot(rows: rows, language: language, updatedAt: updatedAt)
    }

    private func applyRemote(_ snapshot: Snapshot) {
        guard snapshot.updatedAt > updatedAt else { return }
        rows = Timing.sanitize(snapshot.rows)
        language = snapshot.language
        updatedAt = snapshot.updatedAt
        saveLocally()
    }

    private func persist() {
        updatedAt = Date().timeIntervalSince1970
        saveLocally()
        SyncBridge.shared.send(makeSnapshot())
    }

    private func saveLocally() {
        if let data = try? JSONEncoder().encode(rows) {
            UserDefaults.standard.set(data, forKey: rowsKey)
        }
        UserDefaults.standard.set(language, forKey: languageKey)
        UserDefaults.standard.set(updatedAt, forKey: updatedKey)
    }
}
