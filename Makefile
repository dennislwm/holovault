.PHONY: help setup status test run build-ios analyze check-pins clean

help:
	@echo ""
	@echo "Workflow: setup -> analyze -> test -> run"
	@echo ""
	@echo "=== Targets ==="
	@echo "  help          Show this help"
	@echo "  setup         flutter pub get"
	@echo "  status        Check flutter/xcode toolchain"
	@echo "  test          Run flutter test suite"
	@echo "                Requires: setup"
	@echo "  run           flutter run (iOS simulator/device by default)"
	@echo "                Requires: setup"
	@echo "                Requires: ios/ -- see Maintainer setup"
	@echo "                Requires: a booted iOS simulator or connected device"
	@echo "  build-ios     flutter build ios"
	@echo "                Requires: setup"
	@echo "                Requires: ios/ -- see Maintainer setup"
	@echo "  analyze       flutter analyze (static checks/lints)"
	@echo "                Requires: setup"
	@echo "  check-pins    Flag pubspec.yaml dependencies with no version constraint"
	@echo "  clean         flutter clean"
	@echo ""

setup:
	flutter pub get

status:
	@source ./make.sh && show_status

test:
	flutter test

run:
	flutter run

build-ios:
	flutter build ios

analyze:
	flutter analyze

check-pins:
	@source ./make.sh && check_pins

clean:
	flutter clean
