## ADDED Requirements

### Requirement: Continuous integration gate on pull requests and protected branches

The pipeline SHALL run an automated check on every pull request targeting `develop` or `main`, and on every push to `develop` or `main`. The check MUST conclude as failed if any of its steps fail, so it can gate merges and continuously verify the "`main` must always build" invariant.

#### Scenario: Pull request triggers the check

- **WHEN** a pull request targeting `develop` or `main` is opened or updated
- **THEN** the CI workflow runs the check gate against the pull request's commits

#### Scenario: Push to a protected branch triggers the check

- **WHEN** a commit is pushed to `develop` or `main`
- **THEN** the CI workflow runs the check gate against that commit

#### Scenario: Failing step fails the workflow

- **WHEN** any step of the check gate fails
- **THEN** the workflow concludes as failed and reports a failing check status

#### Scenario: All steps passing succeeds the workflow

- **WHEN** every step of the check gate passes
- **THEN** the workflow concludes as successful and reports a passing check status

### Requirement: Check gate scope and local reproducibility

The check gate MUST verify formatting, run static analysis, and run the full test suite covering the host app and both workspace packages (`quran_mcp_server` and `tarteel_qul`). Formatting MUST be verified without modifying any file. The exact gate CI runs MUST be invocable locally through a `just` recipe.

#### Scenario: Gate covers host app and workspace packages

- **WHEN** the check gate runs
- **THEN** it verifies formatting, runs `flutter analyze`, and runs the test suite for the host app and for each of the `quran_mcp_server` and `tarteel_qul` packages

#### Scenario: Formatting is verified, not rewritten

- **WHEN** a Dart source file is not correctly formatted
- **THEN** the format step fails without rewriting the file

#### Scenario: Contributor reproduces the gate locally

- **WHEN** a contributor runs the dedicated CI `just` recipe locally
- **THEN** it performs the same format-check, analyze, and test steps that CI runs

### Requirement: QUL mushaf assets provisioned to CI without committing them

Because `assets/qul/` is gitignored yet declared as Flutter assets in `pubspec.yaml`, the pipeline SHALL populate those files on every runner job that runs `flutter test` or `flutter build`, sourcing them from a maintainer-uploaded GitHub Release asset. The QUL files MUST NOT be added to version control.

#### Scenario: Assets fetched before build/test steps

- **WHEN** a CI or release job that runs `flutter test` or `flutter build` starts
- **THEN** the QUL bundle is downloaded from the designated GitHub Release and extracted into `assets/qul/` before any `flutter test` or `flutter build` step runs

#### Scenario: Cached assets skip the download

- **WHEN** the QUL bundle is already present in the runner cache from a prior run
- **THEN** the job restores it from cache and skips re-downloading the bundle

#### Scenario: QUL files stay out of git

- **WHEN** the change is implemented
- **THEN** no QUL mushaf file is committed to the repository and `assets/qul/` remains gitignored

### Requirement: Release builds on merge to main

When a change merges to `main`, the pipeline SHALL build release binaries for Windows, macOS, and Linux on native runners and package each into a distributable archive named for the platform.

#### Scenario: Merge to main triggers multi-OS builds

- **WHEN** a commit is pushed to `main`
- **THEN** the release workflow runs release builds for Windows, macOS, and Linux

#### Scenario: Each build produces a platform archive

- **WHEN** a platform release build succeeds
- **THEN** it produces a distributable archive identifying the application version and platform

#### Scenario: Failed build blocks the release

- **WHEN** the release build for any platform fails
- **THEN** no GitHub Release is published

### Requirement: Release publication and idempotency

The pipeline SHALL publish a GitHub Release containing the Windows, macOS, and Linux archives, tagged from the application version in `pubspec.yaml`. If a release for the current version already exists, the pipeline MUST skip publication rather than duplicate or overwrite it.

#### Scenario: New version is published

- **WHEN** all three platform builds succeed and no GitHub Release exists for the current `pubspec.yaml` version
- **THEN** a GitHub Release tagged for that version is created with the three platform archives attached

#### Scenario: Unchanged version is not republished

- **WHEN** a merge to `main` does not change the application version and a release for that version already exists
- **THEN** the workflow skips release publication and attaches no new artifacts

### Requirement: Reproducible and least-privilege workflows

CI and release workflows SHALL use a pinned, consistent Flutter toolchain so analysis, formatting, and test results are deterministic. Each workflow MUST request only the GitHub token permissions it needs, and a superseded run on the same ref SHALL be cancelled.

#### Scenario: Pinned toolchain

- **WHEN** any pipeline workflow runs
- **THEN** it provisions an explicitly pinned Flutter SDK version rather than an unpinned channel

#### Scenario: Least-privilege permissions

- **WHEN** the CI check workflow runs
- **THEN** it is granted read-only repository permissions, while only the release workflow is granted permission to write releases

#### Scenario: Superseded runs are cancelled

- **WHEN** a new commit supersedes an in-progress workflow run on the same ref
- **THEN** the older run is cancelled
