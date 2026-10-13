.PHONY: help setup status test run run-release build-ios analyze check-pins clean boot-sim gen-overrides devices

DEVICE ?= iPhone 16

help:
	@echo ""
	@echo "Workflow: setup -> analyze -> test -> boot-sim -> run"
	@echo ""
	@echo "=== Targets ==="
	@echo "  help          Show this help"
	@echo "  setup         flutter pub get"
	@echo "  status        Check flutter/xcode toolchain"
	@echo "  test          Run flutter test suite"
	@echo "                Requires: setup"
	@echo "  run           flutter run (iOS simulator/device by default)"
	@echo "                Requires: setup"
	@echo "                Requires: ios/"
	@echo "                run 'flutter create --platforms=ios --org com.dennislwm --project-name holovault .' once"
	@echo "                Requires: a booted iOS simulator or connected device -- run 'make boot-sim'"
	@echo "  run-release   flutter run --release -- builds a standalone install that keeps working"
	@echo "                after disconnecting from the Mac (a debug build refuses to launch"
	@echo "                without an attached flutter/Xcode session -- iOS blocks ptrace outside it)"
	@echo "                ARGS: extra flutter flags, e.g. ARGS=\"-d <device-id>\""
	@echo "                Requires: setup"
	@echo "                Requires: a booted iOS simulator or connected device -- run 'make boot-sim'"
	@echo "  build-ios     flutter build ios"
	@echo "                Requires: setup"
	@echo "                Requires: ios/"
	@echo "                run 'flutter create --platforms=ios --org com.dennislwm --project-name holovault .' once"
	@echo "  boot-sim      Boot an iOS simulator and open Simulator.app"
	@echo "                DEVICE: $(DEVICE)"
	@echo "                No devices listed at all? run 'make status' to check the iOS runtime is installed"
	@echo "  devices       flutter devices -- list what 'run'/'run-release' can target"
	@echo "                Device shows 'unpaired' (code -29) or is missing? Follow README"
	@echo "                'Physical device testing' (USB, Trust prompt, Xcode Devices window)"
	@echo "  analyze       flutter analyze (static checks/lints)"
	@echo "                Requires: setup"
	@echo "  check-pins    Flag pubspec.yaml dependencies with no version constraint"
	@echo "  clean         flutter clean"
	@echo "  gen-overrides Regenerate override columns from overrides_config.json"
	@echo "                Requires: setup"
	@echo "                Run after editing overrides_config.json"
	@echo ""

setup:
	flutter pub get

status:
	@source ./make.sh && show_status

test:
	flutter test $(ARGS)

run:
	flutter run

run-release:
	flutter run --release $(ARGS)

devices:
	flutter devices

boot-sim:
	@xcrun simctl list devices booted | grep -q "$(DEVICE)" || xcrun simctl boot "$(DEVICE)"
	@open -a Simulator

build-ios:
	flutter build ios

analyze:
	flutter analyze

check-pins:
	@source ./make.sh && check_pins

gen-overrides:
	dart run tool/generate_overrides_schema.dart
	flutter pub run build_runner build --delete-conflicting-outputs

clean:
	flutter clean
