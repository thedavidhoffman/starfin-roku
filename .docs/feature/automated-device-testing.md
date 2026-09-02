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

Copy `tests/automation/.env.example` to `tests/automation/.env.automation` and
enter the host and developer password for one Roku development device, plus the
Jellyfin server and test-account credentials used by the authenticated smoke
test. All values are required. The local environment file is ignored by Git and
its secrets must not be printed, committed, or included in reports.

Run the harness with:

```sh
npm run automation:test
```

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

Screenshots are supporting evidence rather than pixel-diff assertions. They may
not faithfully capture DRM video planes, animation smoothness, overscan, or HDMI
output. Treat result directories as private test artifacts because they may show
server names, account names, Quick Connect codes, or personal media.
