# holovault

A Flutter iOS app for importing and browsing TCG collection data (CSV/JSON).

## Workflow

First run on a fresh checkout: [Maintainer setup](#maintainer-setup) (`flutter create` +
`make setup`) must happen first -- nothing below runs without it.

1. **`make setup`** -- `flutter pub get`. Nothing else runs without this.
2. **`make analyze`** -- static checks/lints. Run before `test` to catch cheap errors first.
3. **`make test`** -- run the test suite.
   - `make coverage` runs the same suite with branch coverage and writes `coverage/lcov.info`.
4. **`make run`** -- launch the app.
   - Requires a booted iOS simulator or connected device.
   - No simulator booted yet? Run `make boot-sim`.
   - No devices listed at all? Run `make status` -- it checks whether an iOS runtime is installed.
   - Testing on a physical device without staying tethered to the Mac? Use `make run-release`
     instead -- see [Physical device testing](#physical-device-testing) below.
   - More than one device connected? Pick one with `DEVICE`, by name or id from `make devices`:
     `make run DEVICE="My iPhone"` or `make run-release DEVICE="My iPhone"`. Without `DEVICE`,
     flutter chooses. Use `ARGS` on `run-release` for other flutter flags, not for the device.

Day-to-day loop is 2 -> 3 -> 4; re-run 1 only when `pubspec.yaml` changes.

## Physical device testing

Requires: a free Apple ID signed into Xcode (Xcode -> Settings -> Accounts) -- no paid Developer Program needed.

One-time device pairing:

1. On the phone: Settings -> Privacy & Security -> Developer Mode -> on, restart, then confirm "Turn On Developer Mode?" after unlock.
   - Missing from Privacy & Security entirely? It appears automatically the first time Xcode tries to install a build -- skip ahead and try step 3, then come back.
2. Plug your iPhone into your Mac and unlock it. Wireless pairing (Xcode -> Window -> Devices and Simulators, "Connect via network") is optional and its exact UI varies by Xcode version -- if you don't see it, stick with USB; it's not required for `make run`.
3. Run `make devices` (wraps `flutter devices`) -- your phone should appear under the connected devices list.
   - Not listed? Check the phone screen for a "Trust This Computer?" prompt (can appear silently after unplug/replug) and accept it. If Xcode's own Devices and Simulators window (Window -> Devices and Simulators) doesn't see it either, it's a cable or port issue, not a Flutter one -- try a different cable (some are charge-only) or a different USB port.
4. `make run` (or `flutter run -d <device-id>`) fails the first time with "No valid code signing certificates were found" -- one manual Xcode step is needed before it can auto-provision anything.
5. Run `open ios/Runner.xcworkspace`.
6. In Xcode's left sidebar, select **Runner** (project), then under TARGETS select **Runner** (target), then the **Signing & Capabilities** tab.
7. In the **Team** dropdown, select your Apple ID. Not listed? Go to Xcode -> Settings -> Accounts -> **+** and sign in first, then come back to this dropdown.
8. In Xcode's toolbar device picker, select your phone as the build target -- this is what registers the device with your account.
9. Re-run `make run` -- it now succeeds and installs the app.
10. On the phone: Settings -> General -> VPN & Device Management -> trust the certificate once.

A free-account certificate expires after 7 days -- re-run `make run` weekly to refresh it. Longer-lived installs need the paid Developer Program, not worth it for testing alone.

`make run` installs a Debug build, which refuses to launch once you disconnect from the Mac -- iOS blocks the `ptrace` access a debug build needs unless `flutter`/Xcode is attached. To keep using the app disconnected, run `make run-release` instead -- same install flow, but the app keeps working standalone (no hot reload/debug console, since it's optimized).

## Diagnostics

    make status      # check flutter/xcode toolchain is installed
    make check-pins  # flag pubspec.yaml dependencies with no version constraint

## List columns and sort

Requires: [ADR-22](https://github.com/dennislwm/holovault/wiki/decisions/adr-22-shared-item-list)

On the Collection, Value trend and Best Returns tabs the strip above the
list sets the sort key and direction, and its Columns button opens a dialog:

1. Tick the fields a row should show.
2. Drag the handles to reorder: the first is the row title, the second the
   subtitle, the rest are listed on the right.
3. Apply. The choice is remembered per tab; unticking everything restores
   that tab's default.

## Export and import custom fields

Requires: [ADR-23](https://github.com/dennislwm/holovault/wiki/decisions/adr-23-export-import-custom-fields)

On the Collection tab, the overflow menu (three dots, after the Import icon)
carries two items that move only the custom-field values, not the collection:

1. **Export custom fields** -- pick a place in the save dialog; the file is
   `holovault-custom-fields-YYYY-MM-DD.json`.
2. **Import custom fields** -- pick such a file. The whole file is checked
   first; if anything is wrong the import is refused and nothing is written.

Rows for items that are no longer imported are kept and exported. Import
skips any column that is no longer declared. A field's key in the file is
`cf<id>` (see [Override columns](#override-columns)); a file keyed by field
names, written before ids existed, imports every row with all values skipped.

## Import the set lookup

Requires: [ADR-24](https://github.com/dennislwm/holovault/wiki/decisions/adr-24-set-language-on-rows)

The set lookup gives each row a language, a set id and an official set name
(columns `language`, `setId` and `setOfficialName`, shown, sorted and filtered
like the custom fields, but read-only). It comes from the sibling repo
`13pyholostatic`, file `data/set_language.json`.

1. Copy `data/set_language.json` to the phone (for example with AirDrop or Files).
2. On the Collection tab, open the overflow menu and tap **Import set lookup**.
3. Pick the file. The whole file is checked first; if anything is wrong the
   import is refused with a reason and the previous lookup stays.
4. A good file replaces the stored lookup. Importing the same file again
   changes nothing.

Only aliases the file marked `exact` for the app `shiny` are used, matched
against the row's set name. A row whose set name has no such alias shows a
blank. When a new set appears in a later collection import, run `make language`
in `13pyholostatic`, copy the new file, and import it again.

## Override columns

Requires: [ADR-03](https://github.com/dennislwm/holovault/wiki/decisions/adr-03-override-schema-extension)

Adding a per-item override column (e.g. a custom note field) is a
developer-time change, not something a user does from the app. Declare it
in `overrides_config.json`, then regenerate:

    make gen-overrides

This writes `lib/database/overrides_schema.dart` from the config and runs
drift's own codegen on top of it, so the new column exists as a real typed
Dart field before the app is rebuilt.

Each entry has a permanent integer `id` (1 or more, written once, never
edited or reused) and a unique `name`. The database column is `cf<id>`, so
renaming an entry keeps its stored values. The `name` is the label and the
Dart getter, so it must be a lower-camel identifier. The same `cf<id>` is the
field's id in saved list settings and its key in the export file. The
generator stops with a message on a missing or repeated id or name.

An app installed before ids existed recreates its custom-field table once on
first open: imported item ids are kept, stored custom values are not.

`make gen-overrides` also writes `overrides_snapshot.json`: each id's last name
and type, a counter, and one step per new id. Commit it with the config and do
not edit it. On the next open an installed app adds the column of each new id
(counter above its stored one). Without the file the generator starts a new
baseline from the current config.

- Rename an entry: keeps its values, no counter change.
- Delete an entry: its column and values stay in the database, hidden.
  Adding the id back with the same type restores them.
- Change an entry's `type`: only `text` and `choice` can swap. Any other
  change stops the generator (the rest of REQ-055 is built in slices).
- Change an `id`: stops the generator when a removed id and a new id share
  a name and type. To start a new field with that name, delete the entry and
  run `make gen-overrides`, then add it back later.

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
