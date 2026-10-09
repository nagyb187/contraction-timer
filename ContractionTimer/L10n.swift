import Foundation

struct Copy: Decodable {
    let appTitle: String
    let subtitle: String
    let awake: String
    let lastInterval: String
    let lastDuration: String
    let noMarks: String
    let emptyHint: String
    let ongoing: String
    let noInterval: String
    let log: String
    let colStart: String
    let colDuration: String
    let colInterval: String
    let first: String
    let copy: String
    let undo: String
    let delete: String
    let cancel: String
    let confirmDelete: String
    let deleted: String
    let undone: String
    let copied: String
    let alreadyRunning: String
    let footnote: String
    let disclaimer: String
    let buttonStart: String
    let buttonEnd: String
    let continueLabel: String
    let language: String
    let secUnit: String
    let minUnit: String
    let countOne: String
    let countMany: String
    let countFew: String?
}

enum Lang: String, CaseIterable, Identifiable {
    case en, de, es, fr, pt, it, pl, nl, ja, hu

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .en: "English"
        case .de: "Deutsch"
        case .es: "Español"
        case .fr: "Français"
        case .pt: "Português"
        case .it: "Italiano"
        case .pl: "Polski"
        case .nl: "Nederlands"
        case .ja: "日本語"
        case .hu: "Magyar"
        }
    }

    var locale: Locale {
        switch self {
        case .en: Locale(identifier: "en_US")
        case .de: Locale(identifier: "de_DE")
        case .es: Locale(identifier: "es_ES")
        case .fr: Locale(identifier: "fr_FR")
        case .pt: Locale(identifier: "pt_PT")
        case .it: Locale(identifier: "it_IT")
        case .pl: Locale(identifier: "pl_PL")
        case .nl: Locale(identifier: "nl_NL")
        case .ja: Locale(identifier: "ja_JP")
        case .hu: Locale(identifier: "hu_HU")
        }
    }

    static var ordered: [Lang] {
        let all = Lang.allCases
        let preferred = Locale.current.language.languageCode?.identifier
        guard let preferred, let match = Lang(rawValue: preferred), match != .en else { return all }
        return [match] + all.filter { $0 != match }
    }
}

enum L10n {
    static let table: [String: Copy] = load()

    static func copy(for code: String) -> Copy {
        table[code] ?? table["en"]!
    }

    static func count(_ n: Int, code: String, copy: Copy) -> String {
        if code == "pl" {
            let mod100 = n % 100
            let mod10 = n % 10
            if mod100 >= 12 && mod100 <= 14 { return String(format: copy.countMany, n) }
            if mod10 >= 2 && mod10 <= 4, let few = copy.countFew { return String(format: few, n) }
            if mod10 == 1 { return copy.countOne }
            return String(format: copy.countMany, n)
        }
        if n == 1 { return copy.countOne }
        return String(format: copy.countMany, n)
    }

    static func formatGap(_ ms: Double, code: String, copy: Copy) -> String {
        guard ms.isFinite, ms >= 0 else { return "—" }
        let totalSeconds = Int((ms / 1000).rounded())
        if code == "ja" {
            if totalSeconds < 600 {
                let minutes = totalSeconds / 60
                let seconds = totalSeconds % 60
                if minutes == 0 { return "\(seconds)秒" }
                return "\(minutes)分\(seconds)秒"
            }
            return "\(Int((ms / 60_000).rounded()))分"
        }
        if totalSeconds < 600 {
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            if minutes == 0 { return "\(seconds) \(copy.secUnit)" }
            return "\(minutes) \(copy.minUnit) \(seconds) \(copy.secUnit)"
        }
        return "\(Int((ms / 60_000).rounded())) \(copy.minUnit)"
    }

    private static func load() -> [String: Copy] {
        guard
            let url = Bundle.main.url(forResource: "strings", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: Copy].self, from: data),
            decoded["en"] != nil
        else {
            fatalError("strings.json missing from the app bundle")
        }
        return decoded
    }
}
