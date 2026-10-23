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
                ForEach(model.rows) { row in
                    DeviceRowView(row: row) { model.select(row) }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: Binding(get: { model.volume }, set: { model.setVolume($0) }), in: 0...1)
                    .disabled(!model.hasVolumeControl)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }

            Toggle("Sticky", isOn: Binding(get: { model.isSticky }, set: { model.setSticky($0) }))

            Divider()

            HStack {
                Text("Switched \(model.switchCount) \(model.switchCount == 1 ? "time" : "times")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 290)
        .onAppear { model.refresh() }
    }
}

struct DeviceRowView: View {
    let row: AudioDeviceRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: row.symbolName)
                    .frame(width: 22)
                Text(row.name)
                    .lineLimit(1)
                Spacer()
                if row.isDefault {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(row.isDefault ? .isSelected : [])
    }
}
