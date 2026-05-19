## Context

The repository has no `.github/` directory and no automated build or test. "`main` must always build" is an unverified convention; releases are never produced. This change adds GitHub Actions CI (the `just check` gate on pull requests and protected-branch pushes) and CD (multi-OS release builds on merge to `main`).

Two project constraints shape the design:

- **Workspace layout.** The root app plus two workspace packages (`quran_mcp_server`, `tarteel_qul`). `just test` already runs `flutter test` three times — root, then each package's `test/` directory. `just check` = `format` + `analyze` + `test`, but `just format` runs `dart format .` which *writes* files; CI must instead *verify* formatting.
- **Gitignored QUL assets (decision D6).** `pubspec.yaml` declares five files under `assets/qul/` as Flutter assets (`qpc-v4-tajweed-15-lines.db`, `qpc-v4.db`, `ttf.zip`, `surah_headers/QCF_SurahHeader_COLOR-Regular.ttf`, `juz_name_font/quran-common.ttf`), but `assets/qul/` is gitignored. A fresh checkout therefore cannot `flutter test` or `flutter build` until those ~70 MB of files are present. CI runs on fresh checkouts, so the pipeline must supply them itself without committing them.

Decided with the requester up front: the release pipeline targets **all three desktop OSes** (Windows, macOS, Linux); CI obtains the QUL assets from a **maintainer-uploaded GitHub Release side-channel**.

## Goals / Non-Goals

**Goals:**

- Run the full `just check` gate (format check, analyze, test — host app + both workspace packages) automatically on every pull request targeting `develop`/`main` and on pushes to those branches.
- On merge to `main`, build release binaries for Windows, macOS, and Linux, package each as a downloadable archive, and publish them as a GitHub Release.
- Populate the gitignored `assets/qul/` on CI runners without committing the files, keeping decision D6 intact.
- Keep workflow steps mirrored by `just` recipes / a composite action so CI is reproducible locally and logic is not buried in YAML.
- Make releases idempotent: a merge that does not change the app version does not republish.

**Non-Goals:**

- Code signing / notarization (macOS Gatekeeper, Windows SmartScreen) — deferred to a later change; this change ships unsigned archives.
- Native installers or store packages — MSIX, `.dmg`, AppImage, `.deb`, Snap. IDEA.md's MVP scope explicitly excludes store releases; this change ships plain `.zip`/`.tar.gz` archives.
- Auto-versioning, changelog generation, or release-notes automation.
- The other AGENTS.md "Planned" hooks (security scan, dependency audit, license compliance, review sub-agents) — each is its own change.
- Test-coverage thresholds, nightly builds, or deploying the MCP server.
- Changing application code, bundled data, or runtime behavior.

## Decisions

### D1 — Two workflows + one composite action

`.github/workflows/ci.yml` (the check gate) and `.github/workflows/release.yml` (build + publish). The shared QUL-asset bootstrap lives in a composite action at `.github/actions/setup-qul-assets/action.yml`, consumed by both.

On a merge to `main`, both workflows fire: `ci.yml`'s `push: main` trigger re-runs the check gate, and `release.yml` builds and publishes. So `release.yml` does **not** duplicate the test job — a failing build is itself the proof that `main` does not build, and the checks already ran (on the PR and again on the push). *Alternative considered:* a single workflow with a `build` job gated by `needs: check` and branch `if:` — rejected because separate files keep the PR-fast-feedback path and the slower release path independently readable. *Alternative considered:* a reusable `workflow_call` check workflow invoked by both — unnecessary once `release.yml` stops re-running checks.

### D2 — CI check job runs on `ubuntu-latest` only

Flutter widget/unit tests execute on the Dart VM, not a device, so they are OS-agnostic; Ubuntu runners are the fastest and cheapest. Cross-platform compilation is proven by the `release.yml` build matrix, not by the check job. *Alternative considered:* a 3-OS test matrix — rejected as redundant runner cost for VM-based tests.

### D3 — `just` drives CI; add non-mutating recipes

Install `just` on runners (`extractions/setup-just`) and add two recipes:

- `format-check` → `dart format --output=none --set-exit-if-changed .` (verifies, never writes — the CI-safe counterpart to `format`).
- `ci` → `format-check analyze test` (the exact gate the workflow runs).

The existing `check` recipe (which *writes* formatting) is left untouched for local use. A contributor can run `just ci` to reproduce CI exactly. This honors AGENTS.md's rule that repeatable workflows are `just` recipes, not ad-hoc YAML. Release builds call `flutter build <os> --release` directly since packaging steps follow inline.

### D4 — QUL assets via a GitHub Release side-channel

A maintainer assembles the five QUL files into one archive `qul-ci-bundle.zip` (preserving the `assets/qul/` subdirectory layout) and uploads it once as an asset on a dedicated, non-code GitHub Release tagged `qul-assets-v1` in this same repository.

The `setup-qul-assets` composite action then, on every job that needs the assets:
1. Restores an `actions/cache` entry keyed on the bundle tag.
2. On cache miss, runs `gh release download qul-assets-v1 --pattern qul-ci-bundle.zip` (authenticated by the workflow's built-in `GITHUB_TOKEN`) and extracts it into `assets/qul/`.
3. Saves the cache so subsequent runs skip the ~70 MB download.

The QUL files never enter git history — decision D6 holds. Updating the bundle = upload a new asset under a new tag (`qul-assets-v2`) and bump the one tag reference in the composite action. `gh` is preinstalled on all runners; `bash` (available on Windows runners too) and `unzip` handle cross-OS extraction.

*Alternatives considered:* **Git LFS** — reverses D6, consumes LFS bandwidth/storage quota, and still redistributes the files in the repo. **Live download from qul.tarteel.ai** — qul.tarteel.ai is an interactive portal with no documented stable direct URLs; brittle and dependent on external uptime. **base64 repo secret** — GitHub secrets cap at 48 KB, far below ~70 MB. **Manually seeded Actions cache** — caches evict after 7 days idle / 10 GB cap, so it cannot be the source of truth.

### D5 — Release matrix, packaging, and artifacts

`release.yml` runs a build matrix on native runners:

| OS | Runner | Build | Package |
|---|---|---|---|
| Windows | `windows-latest` | `flutter build windows --release` | zip `build/windows/x64/runner/Release/` → `quran-companion-<ver>-windows-x64.zip` |
| macOS | `macos-latest` | `flutter build macos --release` | zip the `.app` bundle → `quran-companion-<ver>-macos.zip` |
| Linux | `ubuntu-latest` | `flutter build linux --release` | tar.gz `build/linux/x64/release/bundle/` → `quran-companion-<ver>-linux-x64.tar.gz` |

The Linux job first `apt-get install`s the Flutter Linux toolchain (`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`). Each matrix job uploads its archive via `actions/upload-artifact`. A final `publish` job (`needs:` the matrix) downloads all three and creates the GitHub Release with `gh release create`.

### D6 — Release trigger and idempotency

`release.yml` triggers on `push` to `main`. The `publish` job reads `version:` from `pubspec.yaml`, derives the tag `v<version-without-build-number>` (e.g. `1.0.0+1` → `v1.0.0`), and **skips publishing if a release for that tag already exists**. Releases therefore happen only when a merge bumps the app version — satisfying IDEA.md's "produce releases when changes merge to `main`" without emitting a duplicate release for every doc-only merge. *Alternative considered:* triggering on `push: tags: v*` — cleaner, but IDEA.md specifies the merge-to-`main` trigger; the version gate preserves that trigger while staying sane.

### D7 — Pinned toolchain, least-privilege permissions, concurrency

`subosito/flutter-action@v2` sets up Flutter, pinned to an **exact version** (not the `stable` channel) so `dart format` output and analyzer results are deterministic across runs and match developers' local SDK. `ci.yml` declares `permissions: contents: read`; `release.yml` declares `contents: write` (needed for `gh release create`). Both set a `concurrency` group so superseded runs on the same ref are cancelled. Pub and Flutter SDK caches are enabled.

## Risks / Trade-offs

- **QUL bundle is publicly downloadable if hosted on a public release** → Upload the `qul-assets-v1` release as a **draft** (or prerelease): `gh release download` still retrieves draft assets with the repo-scoped `GITHUB_TOKEN`, but they are not surfaced on the public Releases page. Either way, this is the same KFGQPC-font redistribution the published app binary already performs (see `THIRD_PARTY_NOTICES.md`).
- **macOS/Linux builds are unverified by the team** (only Windows is exercised today) → The first `release.yml` run may fail on macOS/Linux. Treat that as discovery, not regression; fix breakage in this change or a fast follow. CI surfacing it is the point.
- **Unsigned binaries** → Windows SmartScreen and macOS Gatekeeper will warn end users. Documented as a known limitation in `README.md`; signing is a deferred non-goal.
- **macOS runner minutes bill at ~10x** → The 3-OS build matrix runs only on `push: main`, never on pull requests; PRs pay only for the single Ubuntu check job.
- **Cache eviction / cold cache** → On any cache miss the composite action re-downloads the bundle from the release; correctness is unaffected, only speed.
- **Missing `qul-assets-v1` release** → Every workflow fails fast at the bootstrap step; the maintainer setup step (below) is a hard prerequisite and is documented in `README.md`/`AGENTS.md`.
- **Flutter SDK drift** → Pinning an exact version (D7) prevents silent `dart format`/analyzer changes; the pin is bumped deliberately in its own change.

## Migration Plan

1. **Maintainer prerequisite (one-time, manual):** zip the local `assets/qul/` contents into `qul-ci-bundle.zip`, create a draft release tagged `qul-assets-v1`, and upload the asset.
2. Land the composite action, both workflows, the Justfile recipes, and the doc updates via a PR into `develop` — `ci.yml` validates itself on that PR.
3. Merge `develop` → `main` through a release PR; `release.yml` runs for the first time. Fix any macOS/Linux build breakage surfaced.
4. **Maintainer follow-up (manual, GitHub setting):** enable branch protection on `develop` and `main` requiring the CI check to pass before merge.

**Rollback:** the change is purely additive build infrastructure. Deleting `.github/` (or disabling the workflows) removes the pipeline with zero impact on the app, its data, or end users. A bad GitHub Release can be deleted from the Releases page.

## Open Questions

- Exact Flutter version to pin in `subosito/flutter-action` — should match the team's current local SDK; confirm before merge.
- Draft vs. public prerelease for the `qul-assets-v1` release — recommended draft; maintainer's call given the repo's public/private status.
- Branch-protection rules are a GitHub repository setting, not a file in this change — captured as a maintainer follow-up step, not an implementation task.
