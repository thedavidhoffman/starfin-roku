# Automated Device Testing

Starfin uses Roku Test Automation (RTA) for off-device end-to-end smoke tests.
Rooibos remains responsible for unit and SceneGraph component coverage; RTA
validates the deployed application through real Roku launch, ECP, and scene
inspection behavior.

## Build boundary

`bsconfig-automation.json` packages the production application together with
RTA's OnDeviceComponent and enables `enableRta`. The production and Rooibos
builds disable that constant and do not package the RTA device files. Automation
builds are written to `build/automation/` and
`out/starfin-roku-automation.zip` without changing the release build number.

## Local configuration

Copy `tests/automation/.env.automation.example` to
`tests/automation/.env.automation` and
enter the host and developer password for one Roku development device, plus the
Jellyfin server, test-account credentials, and Search expectations used by the
authenticated smoke tests. All values are required. Search expectations are a
JSON array of cases containing a query and optional `moviesAndSeries`, `episodes`,
and `people` title arrays. Every case must configure at least one expected title.
The local environment file is ignored by Git and its values must not be printed,
committed, or included in reports.

Run the harness with:

```sh
npm run automation:test
```

This normal command produces the complete private report and does not redact or
package it. For release-readiness evidence, run:

```sh
npm run automation:test:release
```

Release mode runs the same complete suite, requires every registered test to
pass with no pending, skipped, or unexpected results, and then creates a
credential-safe ZIP. It preserves the private report while masking the server
field in copied Login screenshots. The public copy excludes logs and is scanned
for the configured Jellyfin server, Roku host, Roku developer password, and
Jellyfin password. Fixed loopback and synthetic test values are not secrets.

The runner builds and sideloads the automation package before executing Mocha.
Before any test runs, the suite launches channel `dev`, connects to the
automation-only RTA component, deletes every registry section, verifies no
Starfin-owned section remains, and relaunches the channel. RTA may recreate its
own `rokuTestAutomation` runtime section during this verification. The reset intentionally removes
saved Starfin servers, accounts, tokens, preferences, and navigation state from
the sideloaded development channel so every automation run starts deterministically.

The authenticated smoke test waits for the empty Login screen and captures
evidence. In one ordered flow, it submits the empty form, attempts authentication
against the intentionally unreachable loopback endpoint `127.0.0.1:1`, then checks the
missing-username and missing-password states against the configured server. It also
submits a deliberately incorrect password to verify the reachable server's rejected-
credentials response. Each failed attempt verifies the rendered Login status,
confirms Login remains visible and Home remains hidden, and captures screenshot
evidence. The unreachable-server assertion includes the submitted IP and port while
allowing the reported connection duration to vary.

The test then populates the public server, username, and password fields from
`.env.automation`, captures the populated form with the password masked, selects
Sign In, waits with bounded polling for Home, and captures final Home evidence.
Home readiness requires all attached core tasks to finish, the loading
spinner to clear, at least one shelf to render, no shared status error to remain,
and the rendered shelf/item fingerprint to stay unchanged for a two-second quiet
window. That quiet window accounts for detached per-library Latest Media tasks,
which RTA cannot inspect directly. A short rendering-settle delay follows those
conditions before capture. Secrets are not added to report metadata, though screenshots can show
the configured server and username.

The Search automation spec opens the production Search page and runs every case
from `SEARCH_CASES`. It waits for the real Jellyfin requests and rendered
rows to stabilize, then checks that each configured title appears exactly in its
expected Movies & TV Shows, Episodes, or People section. Additional results and
their ordering are intentionally ignored so unrelated library changes do not
make the assertions brittle. Tests, screenshots, and metadata use case numbers
instead of configured queries or titles.

The movie-library automation specs select the configured library from Home's
My Media row. Letter-grid cases verify every paged result for each configured
letter. Sorting cases use the production Browse dialog and sort-order control,
load the complete grid, and verify ascending and descending Title and Release
Date order. Release Date assertions fall back from `PremiereDate` to
`ProductionYear` and use `SortName` in the requested direction to resolve equal
dates.

Release Date browsing preserves normal server-backed pagination by requesting
`PremiereDate,ProductionYear,SortName` from Jellyfin. The additional fields give
the API a production-year fallback and deterministic title tie-breaker without
loading and sorting the complete library on the Roku.

The library-settings automation spec opens the production Settings overlay and
checks all eight valid presentation-and-column layouts against all eight library
rows. Each layout is selected through the real matrix controls, captured as
screenshot evidence, and saved by closing the dialog. The test then performs a
targeted registry read of only the eight account-scoped library layout keys and
verifies their compound values. Registry sections, tokens, and unrelated account
values are not added to the report.

Separate automation specs cover every selectable value in Media Shell, Playback,
TV, Screensaver, General, Video, and Subtitles. They operate the production
controls and dialog save lifecycle, then read only the affected account-scoped or
global registry key. General includes the real TMDB API-key keyboard flow using a
synthetic value. Advanced verifies that Reset Starfin can be opened and aborted
without changing stored settings or authentication; automation does not confirm
the destructive erase action.

After any settings spec runs, suite teardown restores all eighteen settings to
their canonical defaults and verifies the account and global registry values.
This cleanup preserves authentication, saved accounts, and unrelated registry
data.

## Evidence reports

Each run creates a timestamped directory under `out/automation-results/` with a
Mochawesome `report.html`, report JSON, and a `screenshots/` directory. Report
entries contain relative links to checkpoint images. A failed test attempts an
additional screenshot, but screenshot failure does not replace the original test
error.

A successful release-mode run also creates a `public-report/` copy and a
versioned ZIP in the same timestamped directory. The ZIP contains only the HTML
and JSON reports, screenshots, and a non-sensitive `verification.json` with the
Starfin version, completion time, and aggregate passing counts. Only this ZIP is
suitable for attachment to a public release; the original report and logs remain
private.

Screenshots are supporting evidence rather than pixel-diff assertions. They may
not faithfully capture DRM video planes, animation smoothness, overscan, or HDMI
output. Treat result directories as private test artifacts because they may show
server names, account names, Quick Connect codes, configured Search terms, or
personal media titles and artwork.
