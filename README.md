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
