//
//  AudioMenuView.swift
//  AudioSwitcher
//
//  Thin SwiftUI rendering of AudioMenuViewModel. No logic lives here.
//

import SwiftUI
import AudioCore

struct AudioMenuView: View {
    @ObservedObject var model: AudioMenuViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sound")
                .font(.headline)

            VStack(spacing: 2) {
                ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                    DeviceRowView(row: row, shortcutNumber: index < 9 ? index + 1 : nil) { model.select(row) }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: model.volumeSymbolName).foregroundStyle(.secondary)
                    .frame(width: 16)
                Slider(value: Binding(get: { model.volume }, set: { model.setVolume($0) }), in: 0...1)
                    .disabled(!model.hasVolumeControl)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }

            Toggle("Sticky", isOn: Binding(get: { model.isSticky }, set: { model.setSticky($0) }))

            if model.isLaunchAtLoginAvailable {
                Toggle("Launch at login", isOn: Binding(get: { model.isLaunchAtLoginOn },
                                                        set: { model.setLaunchAtLogin($0) }))
                if let detail = model.launchAtLoginDetail {
                    HStack(spacing: 6) {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if model.loginItemStatus == .requiresApproval {
                            Button("Open Settings") { model.openLoginItemSettings() }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }

            if !model.inputRows.isEmpty {
                Divider()

                Text("Input")
                    .font(.headline)

                VStack(spacing: 2) {
                    ForEach(model.inputRows) { row in
                        DeviceRowView(row: row) { model.selectInput(row) }
                    }
                }
            }

            Divider()

            HStack {
                Text("Switched \(model.switchCount) \(model.switchCount == 1 ? "time" : "times")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 290)
        .onAppear { model.refresh() }
    }
}

struct DeviceRowView: View {
    let row: AudioDeviceRow
    /// 1...9 binds ⌘N to this row (output list only).
    var shortcutNumber: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: row.symbolName)
                    .frame(width: 22)
                Text(row.name)
                    .lineLimit(1)
                Spacer()
                if let n = shortcutNumber {
                    Text("⌘\(n)").font(.caption).foregroundStyle(.secondary)
                }
                if row.isDefault {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .background {
            // Invisible twin carrying the shortcut, so the visible row keeps its custom look.
            if let n = shortcutNumber, let key = n.description.first {
                Button("", action: action)
                    .keyboardShortcut(KeyEquivalent(key), modifiers: .command)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityAddTraits(row.isDefault ? .isSelected : [])
    }
}
