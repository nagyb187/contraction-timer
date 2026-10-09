import SwiftUI

@main
struct ContractionWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Group {
                    if store.language == nil {
                        WatchLanguageList(store: store)
                    } else {
                        WatchLog(store: store)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .background(Color.appBg.ignoresSafeArea())
        }
    }
}

struct WatchLanguageList: View {
    var store: WatchStore

    var body: some View {
        List(Lang.ordered) { lang in
            Button(lang.nativeName) {
                store.setLanguage(lang.rawValue)
            }
            .listRowBackground(Color.appSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBg)
        .navigationTitle(L10n.copy(for: "en").language)
    }
}

struct WatchLog: View {
    var store: WatchStore

    var body: some View {
        let text = store.copy
        ScrollView {
            VStack(spacing: 6) {
                hero(text)
                HStack(spacing: 6) {
                    watchButton(text.buttonStart, active: store.open == nil) { store.begin() }
                    watchButton(text.buttonEnd, active: store.open != nil) { store.finish() }
                }
                recent(text)
            }
            .padding(.horizontal, 4)
        }
        .background(Color.appBg.ignoresSafeArea())
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                store.now = Date()
            }
        }
    }

    private func hero(_ text: Copy) -> some View {
        let rows = store.rows
        let big: String
        let small: String
        if rows.isEmpty {
            big = text.noMarks
            small = text.lastInterval
        } else if rows.count >= 2, let interval = Timing.interval(rows, at: rows.count - 1) {
            big = store.gap(interval)
            if let open = store.open {
                small = "\(text.ongoing) \(store.gap(store.duration(open)))"
            } else if let last = rows.last {
                small = "\(text.lastDuration) \(store.gap(store.duration(last)))"
            } else {
                small = text.noInterval
            }
        } else if let open = store.open {
            big = store.gap(store.duration(open))
            small = text.noInterval
        } else if let last = rows.last {
            big = store.gap(store.duration(last))
            small = text.lastDuration
        } else {
            big = text.noMarks
            small = text.lastInterval
        }
        return VStack(spacing: 0) {
            Text(big)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(small)
                .font(.caption2)
                .foregroundStyle(Color.appMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color.appFg)
        .frame(maxWidth: .infinity)
    }

    private func recent(_ text: Copy) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(store.rows.enumerated().reversed()), id: \.element.id) { pair in
                let index = pair.offset
                let row = pair.element
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.stamp(row.start))
                        .font(.caption2)
                    Text(line(text, index: index, row: row))
                        .font(.caption2)
                        .foregroundStyle(Color.appMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .foregroundStyle(Color.appFg)
    }

    private func line(_ text: Copy, index: Int, row: Contraction) -> String {
        let duration = store.gap(store.duration(row))
        guard let interval = Timing.interval(store.rows, at: index) else {
            return "\(text.colDuration) \(duration)"
        }
        return "\(duration) · \(store.gap(interval))"
    }

    private func watchButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .tint(active ? Color.appPrimary : Color.appSurface)
        .foregroundStyle(active ? Color.appBg : Color.appMuted)
        .disabled(!active)
    }
}
