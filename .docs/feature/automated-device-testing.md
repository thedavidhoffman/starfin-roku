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

The authenticated smoke test waits for the empty Login screen, captures evidence,
populates the public server, username, and password fields from
`.env.automation`, and captures the populated form with the password masked. It
then selects Sign In, waits with bounded polling for Home, and captures final Home
evidence. Home readiness requires all attached core tasks to finish, the loading
spinner to clear, at least one shelf to render, no shared status error to remain,
and the rendered shelf/item fingerprint to stay unchanged for a two-second quiet
window. That quiet window accounts for detached per-library Latest Media tasks,
which RTA cannot inspect directly. A short rendering-settle delay follows those
conditions before capture. Secrets are not added to report metadata, though screenshots can show
the configured server and username.

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
