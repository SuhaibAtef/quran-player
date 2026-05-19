# Quran Player task runner. Run `just` (no args) to list recipes.

# Use PowerShell 7+ on Windows (the project's default shell per CLAUDE.md).
# Non-Windows hosts keep just's default `sh`.
set windows-shell := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

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

# Verify formatting without writing (the CI-safe counterpart to `format`)
format-check:
    dart format --output=none --set-exit-if-changed .

# Run all widget/unit tests (host app + workspace packages)
test:
    flutter test
    flutter test packages/quran_mcp_server/test/
    flutter test packages/tarteel_qul/test/

# Run a single test file: `just test-file test/widget_test.dart`
test-file FILE:
    flutter test "{{FILE}}"

# Run tests matching a name: `just test-name "Counter increments smoke test"`
test-name NAME:
    flutter test --name "{{NAME}}"

# Smoke-test the workspace package + the host-side MCP UI / providers.
mcp-smoke:
    flutter test packages/quran_mcp_server/test/ test/features/mcp_status/mcp_status_page_test.dart test/data/user_db/user_db_graceful_degrade_test.dart

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

# CI gate: the exact format-check + analyze + test the GitHub workflow runs.
# Unlike `check`, this verifies formatting without rewriting files.
ci: format-check analyze test

# Maintainer-only: rebuild assets/quran/quran.sqlite + manifest.json from upstream.
# Requires network access. Idempotent: re-running produces a byte-identical DB.
build-quran-db:
    dart run tool/build_quran_db.dart

# Maintainer-only: rebuild assets/tafsir/muyassar.sqlite + manifest.json from
# the pinned commit of spa5k/tafsir_api. Requires `assets/quran/quran.sqlite`
# to exist already (the tool cross-checks ayah keys against it). Idempotent.
build-tafsir-db:
    dart run tool/build_tafsir_db.dart
