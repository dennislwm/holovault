# holovault

A Flutter iOS app for importing and browsing TCG collection data (CSV/JSON).

## Workflow

First run on a fresh checkout: [Maintainer setup](#maintainer-setup) (`flutter create` +
`make setup`) must happen first -- nothing below runs without it.

1. **`make setup`** -- `flutter pub get`. Nothing else runs without this.
2. **`make analyze`** -- static checks/lints. Run before `test` to catch cheap errors first.
3. **`make test`** -- run the test suite.
4. **`make run`** -- launch the app.
   - Requires a booted iOS simulator or connected device.
   - No simulator booted yet? Run `make boot-sim`.
   - No devices listed at all? Run `make status` -- it checks whether an iOS runtime is installed.

Day-to-day loop is 2 -> 3 -> 4; re-run 1 only when `pubspec.yaml` changes.

## Physical device testing

Requires: a free Apple ID signed into Xcode (Xcode -> Settings -> Accounts) -- no paid Developer Program needed.

One-time device pairing:

1. On the phone: Settings -> Privacy & Security -> Developer Mode -> on, restart, then confirm "Turn On Developer Mode?" after unlock.
   - Missing from Privacy & Security entirely? It appears automatically the first time Xcode tries to install a build -- skip ahead and try step 3, then come back.
2. Plug your iPhone into your Mac and unlock it. Wireless pairing (Xcode -> Window -> Devices and Simulators, "Connect via network") is optional and its exact UI varies by Xcode version -- if you don't see it, stick with USB; it's not required for `make run`.
3. Run `flutter devices` -- your phone should appear under the connected devices list.
   - Not listed? Check the phone screen for a "Trust This Computer?" prompt (can appear silently after unplug/replug) and accept it. If Xcode's own Devices and Simulators window (Window -> Devices and Simulators) doesn't see it either, it's a cable or port issue, not a Flutter one -- try a different cable (some are charge-only) or a different USB port.
4. Run `make run` with the phone selected as the target device -- Xcode auto-provisions a free developer certificate for it.
5. On the phone: Settings -> General -> VPN & Device Management -> trust the certificate once.

A free-account certificate expires after 7 days -- re-run `make run` weekly to refresh it. Longer-lived installs need the paid Developer Program, not worth it for testing alone.

## Diagnostics

    make status      # check flutter/xcode toolchain is installed
    make check-pins  # flag pubspec.yaml dependencies with no version constraint

## Override columns

Requires: [ADR-03](https://github.com/dennislwm/holovault/wiki/decisions/adr-03-override-schema-extension)

Adding a per-item override column (e.g. a custom note field) is a
developer-time change, not something a user does from the app. Declare it
in `overrides_config.json`, then regenerate:

    make gen-overrides

This writes `lib/database/overrides_schema.dart` from the config and runs
drift's own codegen on top of it, so the new column exists as a real typed
Dart field before the app is rebuilt.

## Maintainer setup

Requires: [Flutter SDK](https://docs.flutter.dev/get-started/install)

Requires: [Xcode](https://developer.apple.com/support/xcode/) matching your macOS version -- check that page's compatibility table, then download the right one from [developer.apple.com/download/all](https://developer.apple.com/download/all/) (Apple ID sign-in required)

- The Xcode Command Line Tools alone are not enough -- Simulator.app ships only inside the full Xcode.app.
- Run `make status` to check which one is active and get the exact fix command for your machine.

    brew install --cask flutter
    flutter create --platforms=ios --org com.dennislwm --project-name holovault .
    make setup

## Build

    make build-ios
