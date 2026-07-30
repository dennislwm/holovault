# holovault

A Flutter iOS app for importing and browsing TCG collection data (CSV/JSON).

## Workflow

    make setup    # flutter pub get
    make analyze  # static checks/lints
    make test     # run test suite
    make run      # flutter run

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
