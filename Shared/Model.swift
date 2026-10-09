import Foundation

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

struct Snapshot: Codable, Equatable {
    var rows: [Contraction]
    var language: String?
    var updatedAt: TimeInterval
}

enum Timing {
    static func sanitize(_ rows: [Contraction]) -> [Contraction] {
        var sorted = rows.sorted { $0.start < $1.start }
        if sorted.count > 1 {
            for index in 0..<(sorted.count - 1) where sorted[index].end == nil {
                sorted[index].end = sorted[index + 1].start
            }
        }
        return sorted
    }

    static func interval(_ rows: [Contraction], at index: Int) -> TimeInterval? {
        guard index > 0, index < rows.count else { return nil }
        return rows[index].start - rows[index - 1].start
    }

    static func duration(_ row: Contraction, now: Date) -> TimeInterval {
        let end = row.end ?? now.timeIntervalSince1970
        return max(0, end - row.start)
    }

    static func stamp(_ ts: TimeInterval, language: String?, now: Date) -> String {
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

    static func gap(_ seconds: TimeInterval, language: String?) -> String {
        let code = language ?? "en"
        return L10n.formatGap(seconds * 1000, code: code, copy: L10n.copy(for: code))
    }
}
