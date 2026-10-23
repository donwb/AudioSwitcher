#!/bin/sh
# Renders docs/screenshots/popover-{light,dark,light-requires-approval}.png headlessly with fake devices.
set -e
cd "$(dirname "$0")/.."
T=$(mktemp -d)
swiftc -emit-library -emit-module -module-name AudioCore -parse-as-library \
    -o "$T/libAudioCore.dylib" -emit-module-path "$T/AudioCore.swiftmodule" \
    AudioCore/Sources/AudioCore/*.swift
swiftc -I "$T" -L "$T" -lAudioCore -Xlinker -rpath -Xlinker "$T" -o "$T/render" \
    AudioSwitcher/AudioMenuView.swift scripts/render/main.swift
"$T/render" docs/screenshots
