function check_flutter {
  command -v flutter > /dev/null 2>&1 || { echo "[ERROR][check_flutter]: flutter not installed -- see https://docs.flutter.dev/get-started/install"; return 1; }
  echo "[OK]   flutter found ($(flutter --version 2>&1 | head -1))"
}

function check_xcode {
  command -v xcodebuild > /dev/null 2>&1 || { echo "[ERROR][check_xcode]: xcodebuild not found -- install Xcode for iOS builds"; return 1; }
  local version_output
  version_output=$(xcodebuild -version 2>&1)
  if [ $? -ne 0 ]; then
    echo "[ERROR][check_xcode]: xcodebuild present but not usable -- $(echo "$version_output" | head -1)"
    if [ -d /Applications/Xcode.app ]; then
      echo "[ERROR][check_xcode]: fix: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    else
      echo "[ERROR][check_xcode]: fix: install Xcode.app first (App Store or https://developer.apple.com/download/all/), then sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    fi
    return 1
  fi
  echo "[OK]   xcodebuild found ($(echo "$version_output" | head -1))"
}

function check_ios_runtime {
  command -v xcrun > /dev/null 2>&1 || return 0
  local runtimes
  runtimes=$(xcrun simctl list runtimes 2>/dev/null | grep -c "com.apple.CoreSimulator.SimRuntime.iOS")
  if [ "$runtimes" -eq 0 ]; then
    echo "[ERROR][check_ios_runtime]: no iOS simulator runtime installed"
    echo "[ERROR][check_ios_runtime]: fix: xcodebuild -downloadPlatform iOS"
    return 1
  fi
  echo "[OK]   iOS simulator runtime installed ($runtimes found)"
}

function check_pins {
  local file="pubspec.yaml"
  [ -f "$file" ] || { echo "[ERROR][check_pins]: $file not found"; return 1; }
  local unpinned
  unpinned=$(awk '
    /^dependencies:/ { in_deps=1; next }
    /^dev_dependencies:/ { in_deps=1; next }
    /^[a-zA-Z]/ { in_deps=0 }
    in_deps && /^  [a-zA-Z0-9_]+:[[:space:]]*$/ { print }
  ' "$file" | grep -v '^\s*sdk:' | grep -v 'flutter:\|flutter_test:')
  if [ -n "$unpinned" ]; then
    echo "[ERROR][check_pins]: dependencies with no version constraint:"
    echo "$unpinned"
    return 1
  fi
  echo "[OK]   all pubspec.yaml dependencies have a version constraint"
}

function show_status {
  echo ""
  echo "=== Status ==="
  check_flutter     || true
  check_xcode       || true
  check_ios_runtime || true
  echo "=============="
  echo ""
}
