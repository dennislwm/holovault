.PHONY: help setup status test run build-ios analyze check-pins clean

help:
	@echo ""
	@echo "=== Targets ==="
	@echo "  help          Show this help"
	@echo "  setup         flutter pub get"
	@echo "  status        Check flutter/xcode toolchain"
	@echo "  test          Run flutter test suite"
	@echo "  run           flutter run (iOS simulator/device by default)"
	@echo "  build-ios     flutter build ios"
	@echo "  analyze       flutter analyze (static checks/lints)"
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
