import SwiftUI
import UIKit

struct LanguagePicker: View {
    var store: LogStore
    var firstRun: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: String?

    var body: some View {
        let preview = L10n.copy(for: chosen ?? "en")
        VStack(alignment: .leading, spacing: 0) {
            Text(preview.language)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Color.appFg)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Lang.ordered) { lang in
                        Button {
                            if firstRun {
                                chosen = lang.rawValue
                            } else {
                                store.setLanguage(lang.rawValue)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(lang.nativeName)
                                    .font(.title3.weight(.medium))
                                Spacer()
                                if (firstRun ? chosen : store.language) == lang.rawValue {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .foregroundStyle(Color.appFg)
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            if firstRun {
                Button {
                    if let chosen { store.setLanguage(chosen) }
                } label: {
                    Text(preview.continueLabel)
                        .font(.title2.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .background(chosen == nil ? Color.appSurface : Color.appPrimary, in: Capsule())
                        .foregroundStyle(chosen == nil ? Color.appMuted : Color.appBg)
                }
                .disabled(chosen == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .background(Color.appBg.ignoresSafeArea())
        .foregroundStyle(Color.appFg)
    }
}

struct LogView: View {
    var store: LogStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLanguages = false

    var body: some View {
        let text = store.copy
        VStack(spacing: 0) {
            Color.appPrimary.frame(height: 4)
            VStack(alignment: .leading, spacing: 0) {
                header(text)
                hero(text, now: store.now)
                    .padding(.top, 22)
                if store.rows.isEmpty {
                    Spacer(minLength: 16)
                } else {
                    logCard(text, now: store.now)
                        .padding(.top, 18)
                }
                footer(text)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)
        }
        .background(Color.appBg.ignoresSafeArea())
        .foregroundStyle(Color.appFg)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                store.now = Date()
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = store.awake }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { UIApplication.shared.isIdleTimerDisabled = store.awake }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: store.hapticTick)
        .sheet(isPresented: $showLanguages) {
            LanguagePicker(store: store, firstRun: false)
                .presentationDragIndicator(.visible)
        }
    }

    private func header(_ text: Copy) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text.appTitle)
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                Text(text.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.appMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                Button { showLanguages = true } label: {
                    Image(systemName: "globe")
                        .font(.body.weight(.medium))
                        .frame(width: 44, height: 44)
                        .background(Color.appSurface, in: Circle())
                        .foregroundStyle(Color.appMuted)
                }
                .accessibilityLabel(text.language)
                Button { store.toggleAwake() } label: {
                    Label(text.awake, systemImage: "sun.max")
                        .font(.subheadline.weight(.medium))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(store.awake ? Color.appFg : Color.appSurface, in: Capsule())
                        .foregroundStyle(store.awake ? Color.appBg : Color.appMuted)
                }
                .accessibilityAddTraits(store.awake ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func hero(_ text: Copy, now: Date) -> some View {
        let rows = store.rows
        let open = store.open
        let lastDone = rows.last { $0.end != nil }
        let newestInterval = rows.count >= 2 ? store.interval(at: rows.count - 1) : nil
        let count = L10n.count(rows.count, code: store.language ?? "en", copy: text)

        if rows.isEmpty {
            labeled(text.lastInterval, big: text.noMarks, small: text.emptyHint, bigSize: 36)
        } else if let newestInterval {
            let durationText: String
            if let open {
                durationText = "\(text.ongoing) \(store.gapText(store.duration(open, now: now)))"
            } else if let lastDone {
                durationText = "\(text.lastDuration) \(store.gapText(store.duration(lastDone, now: now)))"
            } else {
                durationText = text.noInterval
            }
            labeled(text.lastInterval, big: store.gapText(newestInterval), small: "\(durationText) · \(count)", bigSize: 48)
        } else if let open {
            labeled(text.ongoing, big: store.gapText(store.duration(open, now: now)), small: text.noInterval, bigSize: 48)
        } else if let lastDone {
            labeled(text.lastDuration, big: store.gapText(store.duration(lastDone, now: now)), small: text.noInterval, bigSize: 48)
        }
    }

    private func labeled(_ label: String, big: String, small: String, bigSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.appMuted)
            Text(big)
                .font(.system(size: bigSize, weight: .semibold, design: .serif))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            Text(small)
                .font(.subheadline)
                .foregroundStyle(Color.appMuted)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func logCard(_ text: Copy, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(text.log)
                Spacer()
                Text("\(store.rows.count)")
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.appMuted)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)

            HStack {
                Text(text.colStart).frame(maxWidth: .infinity, alignment: .leading)
                Text(text.colDuration).frame(maxWidth: .infinity, alignment: .trailing)
                Text(text.colInterval).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(Color.appMuted)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.rows.enumerated()).reversed(), id: \.element.id) { index, row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(store.stamp(row.start, now: now))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(store.gapText(store.duration(row, now: now)))
                                .fontWeight(index == store.rows.count - 1 ? .medium : .regular)
                                .foregroundStyle(index == store.rows.count - 1 ? Color.appFg : Color.appMuted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(store.interval(at: index).map { store.gapText($0) } ?? text.first)
                                .foregroundStyle(Color.appMuted)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.subheadline.monospacedDigit())
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            if index != 0 {
                                Rectangle().fill(Color.appBorder).frame(height: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .frame(maxHeight: .infinity)
    }

    private func footer(_ text: Copy) -> some View {
        VStack(spacing: 12) {
            if !store.rows.isEmpty || store.previous != nil || store.armClear {
                HStack(spacing: 8) {
                    if store.armClear {
                        chip(text.cancel) { store.armClear = false }
                        chip(text.confirmDelete, filled: true) { store.clear() }
                    } else {
                        chip(text.copy, enabled: !store.rows.isEmpty) { store.copyList() }
                        chip(text.undo, enabled: store.previous != nil) { store.undo() }
                        chip(text.delete, enabled: !store.rows.isEmpty) { store.armClear = true }
                    }
                }
            }
            if let banner = store.banner {
                Text(banner)
                    .font(.subheadline)
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: 12) {
                big(text.buttonStart, active: store.open == nil) { store.begin() }
                big(text.buttonEnd, active: store.open != nil) { store.finish() }
            }
            Text(text.footnote)
                .font(.caption)
                .foregroundStyle(Color.appMuted)
                .multilineTextAlignment(.center)
            Text(text.disclaimer)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 14)
    }

    private func chip(_ title: String, filled: Bool = false, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(filled ? Color.appFg : Color.appSurface, in: Capsule())
                .foregroundStyle(filled ? Color.appBg : Color.appFg)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func big(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 76)
                .background(active ? Color.appPrimary : Color.appSurface, in: Capsule())
                .foregroundStyle(active ? Color.appBg : Color.appMuted)
        }
        .disabled(!active)
    }
}

