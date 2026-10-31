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

## Evidence-First, Resumable Execution

Treat clearance as one assessment with persisted progress, not a fresh test run
on every invocation. The intended workflow is a single orchestration command
that discovers evidence, runs missing gates, creates artifacts, and emits the
decision. This document defines that workflow; it does not imply that a complete
orchestrator already exists. Until implemented, maintain the same record manually
under `out/readiness-<version>/`.

Before lengthy checks, perform a preflight:

- Use the version already supplied by the user; ask only if it is missing.
- Confirm the manifest match, baseline, candidate revision, and scoped working
  tree changes. Preserve unrelated work.
- Locate existing Rooibos and RTA results, especially when the user says tests
  have already run. Evaluate their eligibility before scheduling device work.
- Check required credentials without printing them, device reachability and
  current resolution, fixture availability, report-tool dependencies, and local
  browser verification availability. Surface missing prerequisites together.
- Record approved exceptions once, with exact suite/test identities, reason,
  release scope, and authorization. Request a decision only for missing approval;
  never carry a release-specific waiver into another release automatically.
- Exercise report generation and verification against existing evidence or a
  representative fixture before starting hours of device tests. This checks
  tooling readiness; final archives still require verification.
- Announce the missing gates and expected device handoffs together. Do not ask
  for permission to perform checks already authorized by the readiness request.

### Evidence eligibility and invalidation

Persist a private assessment record with the baseline, candidate commit, hashes
of relevant uncommitted files, dependency lockfile and tool versions, effective
build/test configuration, test inventory, fixture identity, device/OS context,
resolution, run IDs, timestamps, exit status, totals, cleanup results, evidence
paths and hashes, exceptions, and each gate's status. Keep credentials out of the
record and device identity out of public reports.

Reuse complete passing evidence when its recorded inputs match the candidate
and required environment. A matching commit alone is insufficient when working
tree files or configuration differ. Historical evidence lacking enough provenance
to establish a match cannot satisfy a gate. Partial runs, unexplained skips,
missing cleanup, and test-runner errors cannot count as a complete pass.

- Production, dependency, fixture, test, or shared-helper changes invalidate
  the gates they affect. Document the dependency reasoning; when uncertain,
  rerun the affected complete suite at both resolutions.
- Documentation-only changes do not invalidate device results.
- Report formatting, redaction, or archive changes invalidate report-tool checks
  and artifact verification, not otherwise matching device execution evidence.
- Refresh dependency advisory checks for each assessment; an unchanged lockfile
  does not establish that external vulnerability information is unchanged.
- Verify the exact final package and archive bytes regardless of evidence reuse.

Record each gate as pending, running, passed, failed, or blocked, together with
whether its evidence was reused or newly produced. Persist progress after each
gate and resume at the first unmet requirement. Recheck inputs on resume, including
after a user response; invalidate only affected gates. Never infer a pass from
an interrupted command. Preserve immutable raw logs, results, and screenshots;
regenerate derived artifacts separately. Existing tools may require separate
commands for these stages; do not rerun device tests merely to invoke packaging.

### Required coverage and manual handoffs

Complete Rooibos coverage and complete RTA coverage at both resolutions remain
required, using eligible existing evidence where available. A future targeted
720p layout/focus suite may replace the second full functional run only after its
coverage is mapped, validated, and explicitly adopted in this procedure and the
runner. Do not silently reduce coverage during an assessment.

When device runs are needed, group them into one planned device-testing window:
perform missing 1080p work, request the switch to 720p once if needed, complete
missing 720p work, then request restoration to 1080p once. Verify actual resolution
after each switch. Skip switches for resolutions with eligible evidence. Request
restoration only when needed; verify the final resolution directly.

Automate archive integrity, privacy, screenshot-reference, asset, and browser
rendering checks. The browser check must cover styling and screenshot expansion,
not just HTML existence. If browser automation is unavailable, prepare both final
reports first and request one consolidated manual review with both paths and the
specific checks. Record the fallback and confirmation. Verify sensitive screenshot
layouts visually when automated coverage cannot establish redaction correctness.
Do not request separate confirmations for every report or repeat a confirmed check
unless the relevant content changes. Byte-identical HTML/assets may retain their
rendering evidence after image-only redaction repairs, with the changed images
separately verified.

Reserve interruptions for necessary physical device changes, missing information,
new exceptions, or decisions that require the user. Optional manual smoke testing
must not become an additional approval gate.

### Approved 2.2.1 audiobook exception

On October 31, 2026, the user authorized skipping these two Home lifecycle RTA
tests for release 2.2.1 while a seekable audiobook fixture is unavailable:

- `saves an interrupted audio position and resumes it when reopened`
- `reports audio completion and removes the item from Continue Listening`

For this release only, those exact pending cases in the resolution-qualified
Home lifecycle suite do not block SHIP. All other tests must execute and pass
at both resolutions. Report totals, actual passes, and both accepted pending
cases separately; never describe the exceptions as passed. The report validator
checks the individual records and preserves the exceptions in archive verification
metadata. Other pending tests, unexecuted tests from incomplete or filtered runs,
failures, and unexpected results remain blockers. This exception overrides the
zero-pending/equal-pass-count requirements below only for these two cases and
does not waive archive or package verification. Resume the current assessment
after authorization, retaining interrupted runs as historical evidence and using
eligible complete runs or executing missing complete suites.

## Classify Test Failures and Stop on Release Blockers

Evaluate gates in dependency order, accepting eligible evidence before executing
missing checks, and assess each result before advancing dependent work.
When a unit test or automation test fails, preserve the evidence and determine
whether the cause is a test defect, a production defect, or an unresolved issue
before proceeding to later readiness steps:

- **Confirmed test defect:** Correct the test and continue the same assessment
  without requesting separate approval for each test repair. Preserve its intended
  behavioral coverage; do not weaken assertions, skip tests, or change production
  code or interfaces to obtain a pass. Base corrections on the intended behavior
  and relevant API contracts, not merely the observed output. Review related
  assertions for the same mistake before rerunning. Record the original failure,
  evidence establishing the test defect, correction, and rerun results. A targeted
  rerun may confirm the fix, but the complete affected suite must pass before SHIP.
- **Confirmed production defect:** Stop and report `NO SHIP` without fixing
  production code during the assessment.
- **Unclear cause:** Stop and report `NO SHIP` with verification blocked by an
  unresolved failure. Do not assume the test is wrong or claim a production defect
  without evidence.

Previously completed checks in the same assessment remain valid when their inputs
are unchanged. Rerun checks affected by the correction. For an automation repair,
this includes a complete run at each resolution affected by the changed test or
shared helper; a resolution-independent change requires both 1080p and 720p.
Regenerate and verify affected reports and archives, preserving private failure
evidence separately. Do not clear the release folder when continuing after a test
repair or present superseded artifacts as current evidence.

At the first confirmed production defect or other hard failure that would prevent
release, stop the review and report `NO SHIP`. Do not continue later checks, start
another resolution's automation run, build release artifacts, or automatically
fix and retry that blocker during the review. Confirmed test and artifact-tooling
defects follow their repair procedures instead.

Examples include an audit finding assessed as a release-blocking security risk
and a production validation failure. Test failures
must first be classified as described above. An outdated dependency or an audit
finding assessed as inapplicable or safe to defer does not trigger this rule.

A report-generation, redaction, or packaging defect blocks delivery of that
artifact, but does not invalidate passing device results. Diagnose and repair
confirmed tooling defects within the assessment, preserve raw evidence, rerun
the affected tooling checks, and regenerate and verify the affected artifacts.
Do not weaken privacy or coverage checks to obtain a pass. An unresolved artifact
failure remains `NO SHIP`; classify failures of unclear origin before proceeding.

When a production blocker or unresolved failure becomes visible during a running
check, stop that check safely
where possible and preserve the available failure evidence. Perform only cleanup
and reporting afterward, including prompting for and verifying restoration to
1080p if the resolution-switching workflow has begun. Cleanup must still happen
after failure; it does not authorize subsequent readiness checks.

Report the failed step, concrete failure evidence, why it blocks release, and
what must be resolved before another review. Mark all unperformed checks and
missing artifacts as `NOT RUN` or `NOT PRODUCED` because the review stopped at
that blocker; do not imply they passed. Once the blocker is resolved, resume
against the updated candidate, retaining only eligible evidence and satisfying
every remaining requirement. Record reused results separately from checks not run.

## Release Artifact Folder and Filenames

Store all final release artifacts in `.release/<version>/` at the project root.
Use the user-confirmed version, matching the package manifest, for both the
folder and filenames. For release `2.1.8`, produce:

```text
.release/2.1.8/
    starfin.2.1.8.zip
    v2.1.8-automation-test-report-1080p.zip
    v2.1.8-automation-test-report-720p.zip
    v2.1.8-release-readiness-report.md
    v2.1.8-unit-test-report.txt
```

The distribution package is named `starfin.<version>.zip`; retain the ZIP
format and extension when copying it from the build output.
The automation ZIP filenames identify the version and resolution, without a
run timestamp. Record the originating run IDs in the readiness report.

After confirming the version and verifying the manifest match, create the
version's release folder. Reconcile existing files with the assessment record;
preserve verified eligible artifacts. Move superseded artifacts to private
historical storage under `out/` before replacing them, checking that resolved
paths remain within the intended workspace directories. Never clear evidence
simply because an assessment was restarted. Preserve other release versions.

Build and automation tools may use `build/` and `out/` as working directories.
Preserve private reports, original screenshots, and raw logs there; place the
sanitized final deliverables in the release folder using the names above.
Treat `.release/` as generated output, outside source review scope.

Verify the final copies in the release folder, including extracting and opening
both automation ZIPs, before recommending `SHIP`.

If the assessment stops at a blocker, write its `NO SHIP` readiness report to
this same folder and retain only artifacts produced or explicitly accepted as
eligible evidence by that assessment.
Mark missing artifacts as `NOT PRODUCED`; never leave an earlier run's files
in place as if they were current evidence.

## 1. Confirm the Release Version

Use the target release version supplied in the request or earlier in the session.
If none was supplied, prompt for it in `major.minor.build` format and wait. Do not
infer the target from the current manifest, package metadata, or previous reports.

Use the confirmed version throughout the decision record, report filenames,
automation archive names, and release artifact. Verify that the Roku manifest's
`major_version`, `minor_version`, and `build_version` match it before proceeding.
If they differ, report the mismatch and resolve it with the user before continuing;
do not silently change or increment the version.

Once the version matches, initialize or reconcile its release folder as specified
in **Release Artifact Folder and Filenames**, then complete preflight and evidence
discovery before proceeding with lengthy checks.

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

Require complete project validation rather than only checks nearest to the
latest changes. Reuse eligible results; execute missing or invalidated checks:

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

Require a complete Rooibos unit-test result matching every release candidate.
When eligible evidence is unavailable, install and test on the configured device:

```text
npm test -- --host <roku-host> --password "<developer-password>"
```

Every unit test must execute and pass. Classify failures under **Classify Test
Failures and Stop on Release Blockers**: repair confirmed test defects and rerun
the complete affected suite within the same assessment; stop for production
defects or unresolved causes. An incomplete run, unexpectedly skipped test, device
disconnect, or test-runner error cannot count as passing evidence. A partial or
targeted rerun is not sufficient for the final release decision.

After the complete Rooibos gate passes, obtain complete RTA evidence at both
resolutions. If neither resolution has eligible evidence, run the coordinator:

```text
npm run automation:test:release:resolutions
```

If only one resolution lacks eligible evidence, use the existing single-resolution
release command (`npm run automation:test:release -- --resolution <resolution>`)
for that resolution. Do not invoke a coordinator that repeats valid runs.
For missing runs, follow this sequence, omitting already satisfied execution gates:

1. Verify that the Roku is set to **1080p**, then run the complete suite in
   release-report mode.
2. Stop and prompt the user to switch the Roku to **720p**. Wait for confirmation,
   verify the actual resolution, then repeat the complete suite in release-report
   mode.
3. Prompt the user to restore **1080p**, wait for confirmation, and verify the
   restoration. Perform this restoration step even after a test failure.

Keep each run's private working reports in a timestamp-first folder:

```text
out/automation-results/<run-id> (1080p)/
out/automation-results/<run-id> (720p)/
```

For example, `2026-09-10T14-56-57-797Z (1080p)`. Each resolution uses its own
run timestamp. Copy its sanitized report ZIP into `.release/<version>/` using
the final filename specified in **Release Artifact Folder and Filenames**,
regardless of the runner's working filename. Each ZIP must contain
the complete HTML and JSON report, its `assets/` directory (including scripts,
styles, fonts, and licenses), verification metadata, and screenshots with
IP addresses redacted. Preserve the private originals and exclude logs from
public archives. Verify both archives' contents, including screenshot redaction
and the absence of exposed IP addresses or credentials in report text and
metadata. Extract each ZIP into a separate directory and verify that the HTML
report renders with its local scripts, styles, fonts, and screenshots available.
Do not attach private reports or logs to a public release.

Redaction verification must cover both image pixels and report data:

- Inspect Login and discovery screenshots, including discovered-server lists,
  the selected server field, and native manual-entry keyboards. Results move
  as lists grow; verify masks at both resolutions rather than applying only
  the Login field rectangle. Unknown discovery screenshot layouts must stop
  packaging until their redaction coverage is defined and tested.
  The initial `discovery-searching` dialog remains unmasked (the mobile-keyboard
  QR-code area is masked): confirm that
  it shows only the searching state, with an empty server field and no results.
- Sanitize and then scan every public HTML and JSON file, including nested or
  escaped context metadata and `verification.json`, for all IPv4 addresses.
  Do not limit this to configured host values: discovery may find other servers.
  Preserve JSON/HTML encoding and the exact loopback exception below. Continue
  checking configured hosts and credentials separately.
- Preserve private originals. Test report generation with unconfigured
  discovered addresses, nested JSON, HTML-encoded metadata, and screenshot
  layouts at both 1080p and 720p. Run `npm run automation:report:test` after
  changing sanitization. Extract the final ZIP and verify its actual contents;
  a successful generator exit or a "credential-safe" label is not sufficient.
- When scanning bundled scripts and styles, distinguish literal template values
  from exposed credentials (especially short passwords); verify matching assets
  against the installed report template rather than blindly replacing values.

The exact loopback address `127.0.0.1` may remain visible in screenshots, report
text, and metadata because it does not identify a private device or server.
This exception also applies to the unit-test report below. All other IP addresses
remain subject to redaction; the exception does not extend to other loopback
addresses or to credentials.

Each resolution must report at least one executed automation test, equal test
and pass counts, and no failed, pending, skipped, or unexpected results, subject
only to explicitly approved release-scoped exceptions recorded above. Both
complete suites must pass and both sanitized archives must pass verification.
A failed or incomplete run cannot satisfy this gate. Confirmed test defects may
be repaired under the classification procedure above, followed by complete
affected runs and archive verification. Production defects, unresolved failures,
missing final archives, or failed archive verification block release. Record each
resolution's aggregate result counts, archive verification result, and sanitized
ZIP path in the decision record.

Capture the complete console output from the final full-suite run in the
versioned unit-test report in `.release/<version>/`. Sanitize the report before
saving it:

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
- Place the verified distribution package in `.release/<version>/` as
  `starfin.<version>.zip` and verify the final copy.
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
- **Test defect:** A confirmed fault in a unit test or automation test. Repair it
  within the assessment while preserving intended coverage, and obtain complete
  passing results from the affected suites before recommending SHIP.
- **Verification blocked:** A failure whose cause remains unresolved. Stop and
  report NO SHIP without assuming either a test defect or a production defect.
- **Follow-up:** A confirmed issue that is safe to defer. Document its impact,
  workaround, and intended follow-up before release.
- **Observation:** A maintainability, consistency, or style concern that does
  not affect the release decision.

Avoid expanding observations into unrelated cleanup during the release review.

## Ship Decision Record

Write the completed decision record to
`.release/<version>/v<version>-release-readiness-report.md`. Record:

- Baseline and proposed release commit.
- User-confirmed target release version and manifest version match.
- Validation commands and results.
- Evidence provenance and input fingerprints, reused versus newly executed gates,
  invalidation reasons, and approved exceptions with actual passes and accepted
  pending cases reported separately. Keep sensitive provenance in private notes.
- Report-tool repairs and regenerated artifacts, including automated verification
  results and any consolidated manual rendering confirmation.
- Test repairs made during the assessment: original failures, evidence supporting
  classification as test defects, corrections, preserved behavioral coverage,
  targeted and complete rerun results, and which earlier checks remain valid
  because their inputs were unchanged.
- Dependency assessment: audit completion and counts by severity, advisory
  applicability and disposition, available fixes, and reasons for accepted or
  inapplicable findings; outdated packages with current/wanted/latest versions
  and update or deferral decisions. Explicitly record when either check reports
  no findings.
- Complete unit-test count and all-passing result.
- Path to the versioned unit-test report.
- Aggregate device-automation result counts for each resolution (1080p and
  720p), originating run IDs, each archive's verification result, and both final
  sanitized report ZIP paths in the release folder.
- Confirmation that 1080p was restored and verified.
- Release artifact version and, when performed, installation and launch results.
- Final release-folder path and artifact filenames.
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
results except explicitly approved release-scoped exceptions, and successful
verification of the final artifacts, including both
sanitized report archives, in `.release/<version>/`. Any accepted
follow-up should have a documented owner and enough detail to be actionable
after release.

End with a concise `SHIP` or `NO SHIP` decision, aggregate results, approved
exceptions or remaining blockers, and links to the package and readiness report.
Distinguish artifact creation from publication; readiness does not publish a release.
