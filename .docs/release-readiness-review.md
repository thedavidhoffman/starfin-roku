# Release Readiness Review

This document defines a bounded review for deciding whether the current
development effort is ready to release. It is a release confidence check, not a
complete audit of the codebase, and should not reopen settled architecture
unless the review uncovers a release-blocking problem.

## Review Outcome

The review should produce a clear ship or no-ship recommendation supported by:

- A review of changes since the last known-good release.
- Automated validation of the complete application.
- Assessment of dependency security findings and available updates.
- A complete unit-test run with all tests passing.
- Complete passing RTA runs at 1080p and 720p, each with a verified sanitized
  report archive.
- Verification of the exact package and configuration intended for release.

Manual verification of critical workflows on a Roku device is recommended but
is not required for the release-readiness analysis to pass.

This process provides reasonable confidence but cannot prove that the release
contains no defects.

## Stop on the First Release Blocker

Run readiness steps sequentially and assess each result before starting the next.
At the first confirmed hard failure that would prevent release, stop the review
and report `NO SHIP`. Do not continue later checks, start another resolution's
automation run, build release artifacts, or automatically fix and retry the
failure during that review.

Examples include an audit finding assessed as a release-blocking security risk,
a failed validation or unit test, and a failed automation run or archive
verification. An outdated dependency or an audit finding assessed as inapplicable
or safe to defer does not trigger this rule.

When a blocker becomes visible during a running check, stop that check safely
where possible and preserve the available failure evidence. Perform only cleanup
and reporting afterward, including prompting for and verifying restoration to
1080p if the resolution-switching workflow has begun. Cleanup must still happen
after failure; it does not authorize subsequent readiness checks.

Report the failed step, concrete failure evidence, why it blocks release, and
what must be resolved before another review. Mark all unperformed checks and
missing artifacts as `NOT RUN` or `NOT PRODUCED` because the review stopped at
that blocker; do not imply they passed or reuse earlier results as current
evidence. Once the blocker is resolved, a new review must satisfy the complete
verification requirements.

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

## 1. Confirm the Release Version

Before starting the review or running any checks, prompt the user for the target
release version in `major.minor.build` format and wait for their response. Do not
infer the target from the current manifest, package metadata, or previous reports.

Use the confirmed version throughout the decision record, report filenames,
automation archive names, and release artifact. Verify that the Roku manifest's
`major_version`, `minor_version`, and `build_version` match it before proceeding.
If they differ, report the mismatch and resolve it with the user before continuing;
do not silently change or increment the version.

## 2. Establish the Release Scope

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

## 3. Perform a Risk-Focused Code Review

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

## 4. Reconcile Behavior and Documentation

- Compare changed behavior with its feature document under `.docs/feature/`.
- Update or create the applicable feature document when release behavior has
  changed.
- Confirm every feature document is listed in `.docs/feature/README.md`.
- Verify that documented limitations and deferred issues still describe the
  proposed release accurately.

## 5. Run Automated Verification

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

Run dependency checks, including development dependencies:

```text
npm audit --include=dev
npm outdated
```

Assess audit findings against how the affected dependency is used during
installation, compilation, testing, packaging, and deployment. Development-only
dependencies can affect the development environment and generated artifacts;
their absence from the Roku package does not by itself make a finding
inapplicable. Review transitive dependencies as well as direct dependencies.

Record the audit counts by severity and, for each advisory, the affected package
and dependency path, applicability, available fix, and disposition: release
blocker, accepted follow-up, or inapplicable with supporting rationale. Unresolved
applicable security risks block release unless explicitly assessed as safe to
defer with a documented owner and rationale. A clean audit establishes only that
no known vulnerabilities were reported.

For outdated dependencies, record current, wanted, and latest versions and the
decision to update or defer. Being behind the latest version is not itself a
release blocker. Make updates deliberately; do not run blanket upgrades or
`npm audit fix --force` as part of readiness checks. After dependency changes,
rerun the checks and complete release validation against the updated lockfile.

Distinguish findings from command failures: a nonzero exit can indicate reported
vulnerabilities or outdated packages. Registry, network, or tooling errors leave
the assessment incomplete and must be resolved before recommending `SHIP`.

## 6. Run Required Roku Device Tests

Install and test on the configured development device. Run the complete Rooibos
unit-test suite for every release candidate:

```text
npm test -- --host <roku-host> --password "<developer-password>"
```

Every unit test must execute and pass. Treat any failed test, incomplete run,
unexpectedly skipped test, device disconnect, or test-runner error as a release
blocker. Stop and report the failure under the stop-on-first-blocker rule. After
the issue is resolved, the next review must rerun the complete suite; a partial
or targeted rerun is not sufficient for the final release decision.

After the complete Rooibos suite passes, run the complete RTA device-automation
suite at both resolutions in release-report mode:

```text
npm run automation:test:release:resolutions
```

Follow this sequence:

1. Verify that the Roku is set to **1080p**, then run the complete suite in
   release-report mode.
2. Stop and prompt the user to switch the Roku to **720p**. Wait for confirmation,
   verify the actual resolution, then repeat the complete suite in release-report
   mode.
3. Prompt the user to restore **1080p**, wait for confirmation, and verify the
   restoration. Perform this restoration step even after a test failure.

Keep each run's reports in a timestamp-first folder:

```text
out/automation-results/<run-id> (1080p)/
out/automation-results/<run-id> (720p)/
```

For example, `2026-09-10T14-56-57-797Z (1080p)`. Each resolution uses its own
run's timestamp and produces a separate sanitized report ZIP. For release
`2.1.8`, name the archives:

```text
starfin-automation-report-v2.1.8-1080p-<run-id>.zip
starfin-automation-report-v2.1.8-720p-<run-id>.zip
```

Use the release artifact's version for subsequent releases. Each ZIP must contain
the complete HTML and JSON report, its `assets/` directory (including scripts,
styles, fonts, and licenses), verification metadata, and screenshots with
IP addresses redacted. Preserve the private originals and exclude logs from
public archives. Verify both archives' contents, including screenshot redaction
and the absence of exposed IP addresses or credentials in report text and
metadata. Extract each ZIP into a separate directory and verify that the HTML
report renders with its local scripts, styles, fonts, and screenshots available.
Do not attach private reports or logs to a public release.

The exact loopback address `127.0.0.1` may remain visible in screenshots, report
text, and metadata because it does not identify a private device or server.
This exception also applies to the unit-test report below. All other IP addresses
remain subject to redaction; the exception does not extend to other loopback
addresses or to credentials.

Each resolution must report at least one executed automation test, equal test
and pass counts, and no failed, pending, skipped, or unexpected results. Both
complete suites must pass and both sanitized archives must pass verification.
A failed or incomplete run, missing archive, or failed archive verification is
a release blocker. Record each resolution's aggregate result counts, archive
verification result, and sanitized ZIP path in the decision record.

Capture the complete console output from the final full-suite run in the
versioned unit-test report under `out/`. Sanitize the report before saving it:

- Normalize the displayed device-test arguments to:

  ```text
  -- --host <ip_redacted> --password "<password_redacted>"
  ```

- Replace every IPv4 address except `127.0.0.1` anywhere in the report with `<ip_redacted>`,
  including the Roku address, local addresses, socket endpoints, and addresses
  repeated in deployment or connection messages.
- Replace the password argument value with `<password_redacted>` without
  replacing occurrences of the password text inside unrelated words, test
  names, or application output. Do not use an unrestricted global replacement
  of the raw password value.
- Redact any other credentials discovered in the output.

After sanitizing, verify that the report contains no IPv4 addresses other than
`127.0.0.1` and no raw credentials. The report must retain the final test totals, result, warnings,
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

## 7. Verify the Release Artifact

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
- User-confirmed target release version and manifest version match.
- Validation commands and results.
- Dependency assessment: audit completion and counts by severity, advisory
  applicability and disposition, available fixes, and reasons for accepted or
  inapplicable findings; outdated packages with current/wanted/latest versions
  and update or deferral decisions. Explicitly record when either check reports
  no findings.
- Complete unit-test count and all-passing result.
- Path to the versioned unit-test report.
- Aggregate device-automation result counts for each resolution (1080p and
  720p), each archive's verification result, and both sanitized report ZIP paths.
- Confirmation that 1080p was restored and verified.
- Release artifact version and, when performed, installation and launch results.
- Open blockers, accepted follow-ups, and known limitations.
- Final decision: `SHIP` or `NO SHIP`.
- Reviewer and review date.

For a review stopped at a blocker, record the first blocking step, failure
evidence, release impact, required remediation, cleanup outcome, and unperformed
checks or missing artifacts. Produce the `NO SHIP` decision record even when
the remaining evidence files could not be generated.

Summarize required Roku execution as pass, fail, or `NOT RUN`. Do not include device
identity, environment details, connection output, deployment output, launch
output, or device-query output in the release-readiness report.

When an optional manual smoke test is performed, also record the server version,
critical workflows tested, and their results in local test notes if useful. Do
not copy device or server identity into the release-readiness report. These
optional fields may be omitted without blocking a `SHIP` decision.

A `SHIP` decision requires no unresolved release blockers, complete passing RTA
suites at both 1080p and 720p with no failed, pending, skipped, or unexpected
results, and successful verification of both sanitized report archives. Any accepted
follow-up should have a documented owner and enough detail to be actionable
after release.
