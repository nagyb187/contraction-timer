import Foundation
import UIKit

@MainActor
@Observable
final class LogStore {
    private let rowsKey = "contractions.v1"
    private let languageKey = "language.v1"
    private let awakeKey = "awake.v1"
    private let updatedKey = "contractions.updatedAt"

    var rows: [Contraction] = []
    var previous: [Contraction]?
    var language: String?
    var awake = false
    var banner: String?
    var armClear = false
    var hapticTick = 0
    var now = Date()

    private var bannerToken = 0
    private var updatedAt: TimeInterval = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: rowsKey),
           let stored = try? JSONDecoder().decode([Contraction].self, from: data) {
            rows = Timing.sanitize(stored)
        }
        language = UserDefaults.standard.string(forKey: languageKey)
        awake = UserDefaults.standard.bool(forKey: awakeKey)
        updatedAt = UserDefaults.standard.double(forKey: updatedKey)
        if updatedAt == 0, !rows.isEmpty || language != nil {
            updatedAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(updatedAt, forKey: updatedKey)
        }
        let bridge = SyncBridge.shared
        bridge.current = { [weak self] in
            self?.makeSnapshot() ?? Snapshot(rows: [], language: nil, updatedAt: 0)
        }
        bridge.onSnapshot = { [weak self] snapshot in
            self?.applyRemote(snapshot)
        }
        bridge.start()
    }

    var copy: Copy {
        L10n.copy(for: language ?? "en")
    }

    var open: Contraction? {
        guard let last = rows.last, last.end == nil else { return nil }
        return last
    }

    func setLanguage(_ code: String) {
        language = code
        UserDefaults.standard.set(code, forKey: languageKey)
        persist()
    }

    func toggleAwake() {
        awake.toggle()
        UserDefaults.standard.set(awake, forKey: awakeKey)
        UIApplication.shared.isIdleTimerDisabled = awake
    }

    func begin() {
        if rows.last?.end == nil && !rows.isEmpty {
            note(copy.alreadyRunning)
            return
        }
        previous = rows
        rows.append(Contraction(start: Date().timeIntervalSince1970, end: nil))
        armClear = false
        persist()
        hapticTick += 1
    }

    func finish() {
        guard let last = rows.last, last.end == nil else { return }
        previous = rows
        rows[rows.count - 1].end = max(Date().timeIntervalSince1970, last.start)
        armClear = false
        persist()
        hapticTick += 1
    }

    func undo() {
        guard let previous else { return }
        rows = previous
        self.previous = nil
        armClear = false
        persist()
        note(copy.undone)
    }

    func clear() {
        previous = rows
        rows = []
        armClear = false
        persist()
        note(copy.deleted)
    }

    func copyList() {
        guard !rows.isEmpty else { return }
        UIPasteboard.general.string = shareText()
        note(copy.copied)
    }

    func interval(at index: Int) -> TimeInterval? {
        Timing.interval(rows, at: index)
    }

    func duration(_ row: Contraction, now: Date = Date()) -> TimeInterval {
        Timing.duration(row, now: now)
    }

    func stamp(_ ts: TimeInterval, now: Date = Date()) -> String {
        Timing.stamp(ts, language: language, now: now)
    }

    func gapText(_ seconds: TimeInterval) -> String {
        Timing.gap(seconds, language: language)
    }

    private func makeSnapshot() -> Snapshot {
        Snapshot(rows: rows, language: language, updatedAt: updatedAt)
    }

    private func applyRemote(_ snapshot: Snapshot) {
        guard snapshot.updatedAt > updatedAt else { return }
        rows = Timing.sanitize(snapshot.rows)
        language = snapshot.language
        updatedAt = snapshot.updatedAt
        previous = nil
        armClear = false
        saveLocally()
    }

    private func shareText() -> String {
        let text = copy
        let formatter = DateFormatter()
        formatter.locale = Lang(rawValue: language ?? "en")?.locale ?? Locale(identifier: "en_US")
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        var lines = [text.appTitle, ""]
        for (index, row) in rows.enumerated() {
            let start = formatter.string(from: Date(timeIntervalSince1970: row.start))
            let end = row.end.map { formatter.string(from: Date(timeIntervalSince1970: $0)) } ?? text.ongoing
            var parts = [
                "\(index + 1). \(start) – \(end)",
                "\(text.colDuration) \(gapText(duration(row)))",
            ]
            if let interval = interval(at: index) {
                parts.append("\(text.colInterval) \(gapText(interval))")
            }
            lines.append(parts.joined(separator: "   ·   "))
        }
        return lines.joined(separator: "\n")
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

    private func note(_ text: String) {
        banner = text
        bannerToken += 1
        let token = bannerToken
        Task {
            try? await Task.sleep(for: .seconds(2.8))
            if bannerToken == token { banner = nil }
        }
    }
}
