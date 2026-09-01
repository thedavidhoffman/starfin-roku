# Starfin Development Guide

This project is open source, and contributions are welcome. If you want to fix
bugs, add features, or improve compatibility, please open an issue or pull
request in this repository so the work remains easy for the community to find.

## Code Foundation

Starfin is not a fork of the Jellyfin Roku client. It uses lessons learned from
the [ABSTV Roku app](https://github.com/thedavidhoffman/abs-tv-roku), a Roku
client for [Audiobookshelf](https://www.audiobookshelf.org/), as its foundation.
The [Jellyfin Roku repository](https://github.com/jellyfin/jellyfin-roku) and
[Roku samples](https://github.com/rokudev/samples) remain useful references.

## Prerequisites

- Node.js and npm.
- A Roku device with developer mode enabled for deployment and debugging.
- The Roku device's IP address and developer password.
- VS Code with the recommended `RokuCommunity.brightscript` extension when using
  the checked-in debug configurations.

The workspace also recommends `AliceBeckett.brightscriptcomment` for comment
formatting and `redhat.vscode-xml` for SceneGraph XML editing. They are optional.

## Setup and Running

Install the locked dependency versions:

```text
npm ci
```

For command-line deployment and direct-socket logging, copy
`rokudeploy.example.json` to `rokudeploy.json` and replace the example host and
password. This file is ignored by Git and must not be committed.

The VS Code debugger does not read `rokudeploy.json`. Configure
`brightscript.debug.host` and `brightscript.debug.password` in your VS Code user
settings, then run the `Starfin` launch configuration. See
[Updating the Roku Debug IP](.docs/roku-debug-ip.md) when the device address
changes.

## Build and Deployment Commands

- `npm run validate` validates and transpiles the project without changing the
  manifest build number. Compiler output is generated under `build/` and `out/`.
- `npm run clean` removes generated `build/` and `out/` content.
- `npm run increment-build-version` increments `build_version` in `manifest`.
- `npm run build` increments the build version, cleans generated output, and
  runs validation.
- `npm run package` runs the build and creates
  `out/starfin.<major>.<minor>.<build>.zip`.
- `npm run deploy` increments the build version, validates, and deploys to the
  Roku configured in `rokudeploy.json`.
- `npm run generate:image-masks` regenerates the checked-in HD mask assets.
- `npm run validate:image-geometry` validates image dimensions and alpha-mask
  geometry.

Use `npm run validate` for routine checks when you do not want to increment the
checked-in manifest version.

## Unit Tests

Starfin uses [Rooibos](https://github.com/rokucommunity/rooibos) for unit
testing. Rooibos runs as a BrighterScript compiler plugin: application code can
remain in standard `.brs` files, while test suites use BrighterScript `.bs`
files for annotations such as `@suite` and `@it`.

The tests execute on a physical Roku device. The test command builds a dedicated
test channel, deploys it to a Roku in developer mode, and streams the results to
the terminal. Little or no test UI may be visible on the television; the
terminal report is authoritative.

Compile the test channel without deploying it:

```text
npm run test:build
```

The generated channel is written to `out/starfin-roku-tests.zip`. To deploy and
run the tests, provide the Roku's IP address and developer password:

```text
npm test -- --host 192.168.1.123 --password "developer-password"
```

A successful run ends with a summary similar to:

```text
Total: 175
Passed: 175
Crashed: 0
Failed: 0
RESULT: Success
[Rooibos Result]: PASS
```

Rooibos framework warnings about unused variables under `pkg:/source/rooibos/`
come from the injected test framework and do not indicate failures in Starfin.
Test specifications live under `tests/rooibos/specs/` and mirror the corresponding
production paths. `bsconfig-test.json` maps them into the test channel's
executable source scope without including them in production packages.
Feature-owned pure helpers remain beside their owning component in the
repository and are mapped into an executable package source directory by the
production and test build configurations.

## Debugging and Logs

The `Starfin` VS Code launch configuration deploys and debugs the channel. It
also writes the Roku debug stream to `logs/rokuDevice.log` while displaying it
in VS Code's **BrightScript Log** output.

Run `npm run logviewer` to start the browser-based viewer in file mode. It tails
`logs/rokuDevice.log`, allowing the VS Code debugger to retain the Roku console
connection.

Run the viewer in direct socket mode when VS Code is not debugging:

```text
npm run logviewer -- --socket
```

Direct socket mode reads the Roku host from `rokudeploy.json` and connects to
port `8085`. Roku permits only one active debug-console connection, so socket
mode cannot run alongside the VS Code debugger.

## Playback Recovery Testing

Use the `Starfin — Playback Chaos Monkey` VS Code launch configuration to test
bounded playback recovery. See
[Playback Chaos Monkey](.docs/playback-chaos-monkey.md) for behavior and logging
details. The checked-in manifest keeps this development-only feature disabled
for normal launches and release packages.
