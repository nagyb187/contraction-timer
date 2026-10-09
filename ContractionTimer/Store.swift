import Foundation
import UIKit

struct Contraction: Codable, Identifiable, Equatable {
    var id: UUID
    var start: TimeInterval
    var end: TimeInterval?

    init(id: UUID = UUID(), start: TimeInterval, end: TimeInterval?) {
        self.id = id
        self.start = start
        self.end = end
    }
}

@MainActor
@Observable
final class LogStore {
    private let rowsKey = "contractions.v1"
    private let languageKey = "language.v1"
    private let awakeKey = "awake.v1"

    var rows: [Contraction] = []
    var previous: [Contraction]?
    var language: String?
    var awake = false
    var banner: String?
    var armClear = false
    var hapticTick = 0
    var now = Date()

    private var bannerToken = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: rowsKey),
           let stored = try? JSONDecoder().decode([Contraction].self, from: data) {
            rows = stored.sorted { $0.start < $1.start }
            if rows.count > 1 {
                for index in 0..<(rows.count - 1) where rows[index].end == nil {
                    rows[index].end = rows[index + 1].start
                }
            }
        }
        language = UserDefaults.standard.string(forKey: languageKey)
        awake = UserDefaults.standard.bool(forKey: awakeKey)
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
        guard index > 0 else { return nil }
        return rows[index].start - rows[index - 1].start
    }

    func duration(_ row: Contraction, now: Date = Date()) -> TimeInterval {
        let end = row.end ?? now.timeIntervalSince1970
        return max(0, end - row.start)
    }

    func stamp(_ ts: TimeInterval, now: Date = Date()) -> String {
        let date = Date(timeIntervalSince1970: ts)
        let formatter = DateFormatter()
        formatter.locale = Lang(rawValue: language ?? "en")?.locale ?? Locale(identifier: "en_US")
        if Calendar.current.isDate(date, inSameDayAs: now) {
            formatter.dateStyle = .none
            formatter.timeStyle = .medium
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
        }
        return formatter.string(from: date)
    }

    func gapText(_ seconds: TimeInterval) -> String {
        L10n.formatGap(seconds * 1000, code: language ?? "en", copy: copy)
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
        if let data = try? JSONEncoder().encode(rows) {
            UserDefaults.standard.set(data, forKey: rowsKey)
        }
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
