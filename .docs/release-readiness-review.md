# Release Readiness Review

This document defines a bounded review for deciding whether the current
development effort is ready to release. It is a release confidence check, not a
complete audit of the codebase, and should not reopen settled architecture
unless the review uncovers a release-blocking problem.

## Review Outcome

The review should produce a clear ship or no-ship recommendation supported by:

- A review of changes since the last known-good release.
- Automated validation of the complete application.
- A complete unit-test run with all tests passing.
- Verification of the exact package and configuration intended for release.

Manual verification of critical workflows on a Roku device is recommended but
is not required for the release-readiness analysis to pass.

This process provides reasonable confidence but cannot prove that the release
contains no defects.

## Release Evidence Files

Store the completed review evidence under `out/`, using the version embedded in
the release artifact:

```text
out/v<major>.<minor>.<build>-release-readiness-report.md
out/v<major>.<minor>.<build>-unit-test-report.txt
```

For example, release `2.0.3` produces:

```text
out/v2.0.3-release-readiness-report.md
out/v2.0.3-unit-test-report.txt
```

These are generated release outputs and should not be treated as source files.
Replace existing reports for the same version when the complete verification is
rerun so the files always describe the latest run of that candidate.

## 1. Establish the Release Scope

- Identify the last known-good release tag, commit, or branch.
- Review the diff from that baseline to the proposed release commit.
- List the user workflows, shared helpers, components, tasks, configuration,
  and assets affected by those changes.
- Confirm that the diff does not contain accidental files, generated output,
  development credentials, debug-only behavior, abandoned feature flags, or
  unfinished work intended for a later release.
- Treat unrelated working-tree changes as user-owned and keep them outside the
  review scope.
- Do not use `.to-do.md` as release scope unless its owner explicitly requests
  it.

## 2. Perform a Risk-Focused Code Review

Review changed production code and the directly connected callers, consumers,
and tests. Do not inspect unrelated historical code solely for completeness.

Give additional attention to changes involving:

- Authentication, session expiry, and persisted session data.
- API request construction, response handling, and error paths.
- Asynchronous request correlation and stale responses.
- Playback lifecycle, progress reporting, queues, and recovery.
- Navigation, focus movement, focus restoration, and Back-button behavior.
- Dialog and overlay opening, dismissal, selection, and returned focus.
- Persistence, restoration, and transitions between application modes.

For stateful workflows, trace the complete event sequence and confirm that
state and side effects have clear owners. Look for obsolete workarounds or
alternate paths that bypass the current implementation.

## 3. Reconcile Behavior and Documentation

- Compare changed behavior with its feature document under `.docs/feature/`.
- Update or create the applicable feature document when release behavior has
  changed.
- Confirm every feature document is listed in `.docs/feature/README.md`.
- Verify that documented limitations and deferred issues still describe the
  proposed release accurately.

## 4. Run Automated Verification

Run the complete project validation rather than only the tests nearest to the
latest changes:

```text
npm run validate
npm run test:build
git diff --check
```

`npm run test:build` confirms that the complete unit-test project compiles, but
it does not execute the tests. Review warnings, unexpected output, and test
coverage of changed behavior instead of relying only on a successful exit code.
A successful build does not verify SceneGraph runtime behavior.

## 5. Run Required Roku Device Tests

Install and test on the configured development device. Run the complete Rooibos
unit-test suite for every release candidate:

```text
npm test -- --host <roku-host> --password "<developer-password>"
```

Every unit test must execute and pass. Treat any failed test, incomplete run,
unexpectedly skipped test, device disconnect, or test-runner error as a release
blocker until it is understood and resolved. Rerun the complete suite after the
resolution; a partial or targeted rerun is not sufficient for the final release
decision.

Capture the complete console output from the final full-suite run in the
versioned unit-test report under `out/`. Sanitize the report before saving it:

- Normalize the displayed device-test arguments to:

  ```text
  -- --host <ip_redacted> --password "<password_redacted>"
  ```

- Replace every IPv4 address anywhere in the report with `<ip_redacted>`,
  including the Roku address, local addresses, socket endpoints, and addresses
  repeated in deployment or connection messages.
- Replace the password argument value with `<password_redacted>` without
  replacing occurrences of the password text inside unrelated words, test
  names, or application output. Do not use an unrestricted global replacement
  of the raw password value.
- Redact any other credentials discovered in the output.

After sanitizing, verify that the report contains no IPv4 addresses or raw
credentials. The report must retain the final test totals, result, warnings,
crashes, failures, and ignored-test count.

Record the total test count, passing result, and unit-test report path in the
release decision record. Do not store the developer password in the repository,
release evidence, or command examples.

Do not copy Roku device output or device-identifying details into the release-
readiness report. Record only the aggregate unit-test result and counts. Exclude:

- Roku model and model number.
- Roku OS version and build number.
- IP addresses, ports, socket endpoints, and connection details.
- Device uptime.
- Application or developer-channel ID.
- Jellyfin server version.
- Deployment, launch, debug-console, and device-query transcripts.

## Optional Manual Roku Smoke Test

The manual smoke test is a recommended confidence-building activity, especially
for broad changes or changes involving visual layout, focus, navigation,
playback, persistence, or device-specific behavior. It is non-blocking and does
not need to be performed or documented for the release-readiness analysis to
pass.

Manually exercise the critical paths applicable to the release:

- Cold launch and launch with a persisted authenticated session.
- Login, logout, and expired-session handling.
- Navigation between major surfaces and focus recovery.
- Home and library loading, empty states, and API failures.
- Item selection and drill-down navigation.
- Playback start, pause, resume, seek, exit, and progress restoration.
- Playback queue advancement when applicable.
- Dialog opening, dismissal, selection, and returned focus.
- Back-button behavior from every major surface.
- Application relaunch after persisted state has been created.

Record the device model, Roku OS version, server version, and release commit so
the result can be reproduced locally when a manual smoke test is performed, but
do not include those device or server details in the generated release-readiness
report. An absent or incomplete manual smoke-test record is not a release
blocker.

## 6. Verify the Release Artifact

- Build the exact package intended for distribution.
- Confirm its version and channel configuration.
- Confirm production endpoints and release configuration are selected.
- Confirm required images, fonts, and other packaged assets are present.
- Confirm the artifact contains no development credentials or debug-only
  configuration.
- Optionally install the release artifact fresh instead of relying only on an
  existing development side-load.
- When the artifact is installed, confirm that it launches successfully and
  optionally repeat a short critical-path smoke test.

Fresh installation and launch verification are recommended confidence-building
checks, but they are not required for the release-readiness analysis to pass.

## Finding Classification

Classify each finding before making the release decision:

- **Release blocker:** A crash, broken primary workflow, data or session
  corruption, security issue, unusable navigation or focus, failed validation,
  or invalid release package. The release should not ship until resolved and
  reverified.
- **Follow-up:** A confirmed issue that is safe to defer. Document its impact,
  workaround, and intended follow-up before release.
- **Observation:** A maintainability, consistency, or style concern that does
  not affect the release decision.

Avoid expanding observations into unrelated cleanup during the release review.

## Ship Decision Record

Write the completed decision record to the versioned release-readiness report
under `out/`. Record:

- Baseline and proposed release commit.
- Validation commands and results.
- Complete unit-test count and all-passing result.
- Path to the versioned unit-test report.
- Release artifact version and, when performed, installation and launch results.
- Open blockers, accepted follow-ups, and known limitations.
- Final decision: `SHIP` or `NO SHIP`.
- Reviewer and review date.

Summarize required Roku execution only as pass or fail. Do not include device
identity, environment details, connection output, deployment output, launch
output, or device-query output in the release-readiness report.

When an optional manual smoke test is performed, also record the server version,
critical workflows tested, and their results in local test notes if useful. Do
not copy device or server identity into the release-readiness report. These
optional fields may be omitted without blocking a `SHIP` decision.

A `SHIP` decision requires no unresolved release blockers. Any accepted
follow-up should have a documented owner and enough detail to be actionable
after release.
