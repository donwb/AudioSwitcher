# AudioSwitcher (AudioSticker)

A macOS menu bar app for choosing the audio output device and its volume. It's a personal project.

## Layout

- `AudioSwitcher/`: the AppKit app (the product name is **AudioSticker**). `AudioSwitcherApp.swift` (a SwiftUI `MenuBarExtra`, `.window` style) and `AudioMenuView.swift` hold the UI; all state and behaviour is in AudioCore's `AudioMenuViewModel`.
- `AudioCore/`: a local Swift package that holds the audio logic and its tests. It talks to CoreAudio directly, with no third-party wrapper.
  - `AudioCore.swift` defines the `AudioState`, `AudioOutputDevice` and `AudioDeviceProvider` protocols and Sticky.
  - `NativeCoreAudio.swift`, `PropertyStore.swift` and `VolumeControl.swift` talk to the hardware.
  - `DefaultOutputMonitor.swift` watches for changes to the default output device.
- `AudioSwitcherTests/` and `AudioSwitcherUITests/` are Xcode test targets. They can't run headless here, so don't rely on them.

## Build and test

```
cd AudioCore && swift test                      # the real test suite
xcodebuild -scheme AudioSticker -destination platform=macOS CODE_SIGNING_ALLOWED=NO build
```

Both must pass before you open a PR. Code signing isn't available, and there is no GUI session, so you can't launch the app. Say so under "Not verified".

## Where code goes

- **Put new logic in AudioCore, not in the app.** SwiftUI views should only render `AudioMenuViewModel` and forward events to it. SwiftPM picks up new files in AudioCore automatically. A new file in the app target needs `project.pbxproj` edits, so avoid that.
- **Test with fakes.** Use `FakeProvider` / `FakeOutputDevice` (in `AudioStateTests.swift`) and `FakePropertyStore` (in `VolumeControlTests.swift`). For settings, use a throwaway `UserDefaults(suiteName:)` and remove it in `tearDown`.
- **Tests must never change real audio.** No test may change the real default output device or volume. `LiveDeviceTests` are read-only and must stay that way. Anything that switches devices or sets volume is tested through fakes.
- Each behaviour you add or fix gets at least one test. Never delete or weaken a test to make the suite pass.
- Match the surrounding code. `AudioState` uses PascalCase method names (`MakeActiveOutputDevice`, `SetSticky`); keep that inside `AudioState` and don't rename existing API.
- Devices are matched by **name** throughout. CoreAudio device IDs aren't stable across reboots, so don't save IDs. If you need a stable identity, use the device UID.
- The macOS minimum is declared in two places, and they must match: the app target's `MACOSX_DEPLOYMENT_TARGET` in `project.pbxproj`, and `platforms:` in `AudioCore/Package.swift`.

## Git and PRs

1. Start from an up-to-date `main` (`git checkout main && git pull origin main`).
2. **Create a new branch for every goal:** `hermes/<short-name>`. Never reuse a branch, even if its PR merged.
3. Never push to `main`; it's protected. Every change goes through a PR.
4. Commit, then `git push -u origin <branch>`, then `gh pr create --base main`. The PR body has three sections:
   - **What changed**
   - **How it was verified** (commands run and the test count)
   - **Not verified** (be specific, e.g. "did not launch the app")
5. Stay inside the goal. If you notice adjacent work, list it in the PR as a suggested follow-up, but don't do it.
