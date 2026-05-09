# Quran Player task runner. Run `just` (no args) to list recipes.

# List available recipes
default:
    @just --list

# Install Dart/Flutter dependencies
get:
    flutter pub get

# Upgrade dependencies to latest allowed versions
upgrade:
    flutter pub upgrade

# Static analysis (lints + type errors). Run before committing.
analyze:
    flutter analyze

# Format all Dart files
format:
    dart format .

# Run all widget/unit tests
test:
    flutter test

# Run a single test file: `just test-file test/widget_test.dart`
test-file FILE:
    flutter test "{{FILE}}"

# Run tests matching a name: `just test-name "Counter increments smoke test"`
test-name NAME:
    flutter test --name "{{NAME}}"

# List connected devices and emulators
devices:
    flutter devices

# Launch on a device. Default: windows. e.g. `just run chrome`
run DEVICE="windows":
    flutter run -d {{DEVICE}}

# Release build. e.g. `just build apk` / `just build windows` / `just build web`
build TARGET:
    flutter build {{TARGET}}

# Wipe build outputs and reinstall dependencies
clean:
    flutter clean
    flutter pub get

# Pre-commit gate: format, analyze, test
check: format analyze test
