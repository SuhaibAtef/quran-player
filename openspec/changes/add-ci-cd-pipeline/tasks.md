## 1. Branch setup

- [x] 1.1 Create branch `feature/add-ci-cd-pipeline` from `develop` (the localization branch is already merged into `develop`)

## 2. QUL CI bundle (maintainer prerequisite)

- [x] 2.1 Assemble `qul-ci-bundle.zip` from the local `assets/qul/` contents, preserving the subdirectory layout (the 3 root files plus `surah_headers/` and `juz_name_font/`)
- [x] 2.2 Create a **draft** GitHub Release tagged `qul-assets-v1` in this repo and upload `qul-ci-bundle.zip` as its asset
- [x] 2.3 Verify `gh release download qul-assets-v1 --pattern qul-ci-bundle.zip` succeeds with a repo-scoped token

## 3. Justfile recipes

- [x] 3.1 Add a `format-check` recipe: `dart format --output=none --set-exit-if-changed .` (verifies formatting without writing)
- [x] 3.2 Add a `ci` recipe composing `format-check`, `analyze`, and `test` (the exact gate CI runs); leave the existing `check` recipe untouched
- [x] 3.3 Run `just ci` locally and confirm it reproduces the gate

## 4. QUL setup composite action

- [x] 4.1 Create `.github/actions/setup-qul-assets/action.yml` as a composite action
- [x] 4.2 Step: restore an `actions/cache` entry for `assets/qul/` keyed on the `qul-assets-v1` tag
- [x] 4.3 Step (on cache miss): `gh release download qul-assets-v1 --pattern qul-ci-bundle.zip` using `GITHUB_TOKEN`, then extract into `assets/qul/` via `bash` + `unzip` so it works on Windows, macOS, and Linux runners
- [x] 4.4 Confirm the action fails fast with a clear message if the release/asset is missing

## 5. CI workflow

- [x] 5.1 Create `.github/workflows/ci.yml` triggered on `pull_request` and `push` for `develop` and `main`, with `permissions: contents: read` and a `concurrency` group that cancels superseded runs
- [x] 5.2 Add a `check` job on `ubuntu-latest`: checkout, `subosito/flutter-action@v2` (pinned exact Flutter version), `extractions/setup-just`, pub + SDK caching, `flutter pub get`
- [x] 5.3 Invoke the `setup-qul-assets` composite action before any test step
- [x] 5.4 Run the gate via `just ci`

## 6. Release workflow

- [x] 6.1 Create `.github/workflows/release.yml` triggered on `push` to `main`, with `permissions: contents: write` and a `concurrency` group
- [x] 6.2 Add a `build` matrix job over `windows-latest` / `macos-latest` / `ubuntu-latest`: checkout, setup Flutter (same pin), `setup-qul-assets`, `flutter pub get`
- [x] 6.3 On the Linux runner, `apt-get install` the Flutter Linux toolchain (`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`)
- [x] 6.4 Run `flutter build <os> --release` per matrix entry and package the output: zip the Windows runner `Release/` folder, zip the macOS `.app`, tar.gz the Linux `bundle/`; name each `quran-companion-<version>-<platform>` and upload via `actions/upload-artifact`
- [x] 6.5 Add a `publish` job with `needs:` the build matrix: read `version:` from `pubspec.yaml`, derive tag `v<version-without-build-number>`
- [x] 6.6 Skip publication if a release for that tag already exists; otherwise download all three artifacts and create the GitHub Release with `gh release create`

## 7. Documentation

- [x] 7.1 Update `AGENTS.md`: add a CI/CD subsection, refresh the project-state notes, the Justfile recipe table (new `format-check`/`ci` recipes), and the "Planned" hooks wording now that the pipeline exists
- [x] 7.2 Update `README.md`: add a CI/release section, document the `qul-assets-v1` CI bundle and how to refresh it, and note that released binaries are unsigned (SmartScreen/Gatekeeper warnings)

## 8. Verification

- [x] 8.1 Run `just check` locally and confirm it passes before opening the PR
- [ ] 8.2 Open the PR into `develop`; confirm `ci.yml` runs and passes, and that an intentionally misformatted file makes `format-check` fail (then revert)
- [ ] 8.3 After merge to `main`, confirm `release.yml` builds all three OSes; fix any macOS/Linux build breakage surfaced, and confirm the GitHub Release is created (or skipped when the version is unchanged)
- [ ] 8.4 Maintainer follow-up: enable branch protection on `develop`/`main` requiring the CI check to pass before merge
