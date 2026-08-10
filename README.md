# holovault

A Flutter iOS app for importing and browsing TCG collection data (CSV/JSON).

## Workflow

First run on a fresh checkout: [Maintainer setup](#maintainer-setup) (`flutter create` +
`make setup`) must happen first -- nothing below runs without it.

1. **`make setup`** -- `flutter pub get`. Nothing else runs without this.
2. **`make analyze`** -- static checks/lints. Run before `test` to catch cheap errors first.
3. **`make test`** -- run the test suite.
4. **`make run`** -- launch the app (simulator or connected device).

Day-to-day loop is 2 -> 3 -> 4; re-run 1 only when `pubspec.yaml` changes.

## Diagnostics

    make status      # check flutter/xcode toolchain is installed
    make check-pins  # flag pubspec.yaml dependencies with no version constraint

## Maintainer setup

Requires: [Flutter SDK](https://docs.flutter.dev/get-started/install)

Requires: [Xcode](https://developer.apple.com/support/xcode/) matching your macOS version -- check that page's compatibility table, then download the right one from [developer.apple.com/download/all](https://developer.apple.com/download/all/) (Apple ID sign-in required)

    brew install --cask flutter
    flutter create --org com.dennislwm --project-name holovault .
    make setup

## Build

    make build-ios
