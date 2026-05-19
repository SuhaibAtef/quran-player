## Why

IDEA.md's V1 "Distribution" group calls for GitHub CI/CD that produces releases when changes merge to the main branch, plus desktop packaging for Windows, macOS, and Linux. Today none of that exists: the project has no `.github/` workflows, so the stated invariant "`main` must always build" rests entirely on contributors remembering to run `just check`, and no installable build is ever produced. The MVP plus several V1 changes have stabilized the foundation — before more V1 features land, an automated gate should keep `develop` and `main` green and turn every merge to `main` into downloadable desktop builds.

## What Changes

- Add a **continuous-integration workflow** that runs on pull requests targeting `develop` and `main` (and on pushes to those branches): the `just check` gate — `dart format` check, `flutter analyze`, `flutter test` — plus the `quran_mcp_server` and `tarteel_qul` workspace package test suites.
- Add a **release workflow** that runs on push to `main`: build release binaries for Windows, macOS, and Linux on their native GitHub runners, package each into a distributable archive, and publish a GitHub Release with the three artifacts attached. The release version is derived from `pubspec.yaml`; a merge whose version already has a release is skipped so doc-only merges don't spam releases.
- Establish a **QUL-asset bootstrap for CI**: because `assets/qul/` is gitignored (decision D6) yet `pubspec.yaml` declares those files as Flutter assets, both workflows must populate them before `flutter test`/`flutter build`. A maintainer uploads the ~70 MB QUL bundle once as an asset on a dedicated, non-code GitHub Release tag; workflows fetch it with `gh release download` and cache it. The QUL files stay out of git.
- Add Justfile recipe(s) / scripts so the QUL-asset bootstrap and packaging steps mirror local commands rather than living only inside YAML.
- Document the pipeline (CI gate, release process, the QUL CI bundle, runner matrix) in `AGENTS.md` and `README.md`, and update the project-state notes.

No application code or runtime behavior changes — this is build/release infrastructure only.

## Capabilities

### New Capabilities

- `ci-cd-pipeline`: Automated GitHub Actions continuous integration (the `just check` gate plus workspace package tests on pull requests and protected-branch pushes) and continuous delivery (multi-OS release builds, packaging, and GitHub Release publication on merge to `main`), including the mechanism that supplies the gitignored QUL mushaf assets to CI runners without committing them.

### Modified Capabilities

<!-- None. The pipeline is additive build/release infrastructure; no existing spec's
     requirements change. Documentation updates to AGENTS.md/README.md follow the
     repo's "Keep docs current" rule but do not alter agent-guidance requirements. -->

## Impact

- **New files**: `.github/workflows/` CI and release workflow definitions; CI/packaging helper script(s); new `Justfile` recipes.
- **Repository / GitHub**: a one-time maintainer action creates a dedicated GitHub Release tag holding the QUL CI bundle; branch protection on `develop`/`main` can later require the CI check.
- **Assets**: `assets/qul/` is populated on CI runners from the side-channel release; it remains gitignored and uncommitted.
- **Docs**: `AGENTS.md` (CI/CD section, project-state notes, "Planned hooks" wording) and `README.md` (release/CI section, QUL CI bundle note).
- **Dependencies**: GitHub-hosted runners (`windows-latest`, `macos-latest`, `ubuntu-latest`), a Flutter SDK setup action, and `gh` CLI (preinstalled on runners). No new Dart/Flutter package dependencies.
- **No impact** on app runtime, the MCP server, bundled Quran/tafsir data, or end users — published builds still embed the QUL assets in the binary exactly as today.
