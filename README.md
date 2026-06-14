[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/thedavidhoffman)

This project is open source, and contributions are welcome. If you're interested in improving this app, please consider opening an issue or pull request here rather than creating a separate forked version. Keeping development centered in this repository helps avoid duplicate work, makes improvements easier for everyone to find, and gives the community a single place to collaborate.

Forks are part of open source but if your goal is to fix bugs, add features, or improve compatibility, contributing those changes back here is greatly appreciated.

# ROKU STARTER KIT

This repository contains a starter Roku application. It has the base foundation for a Roku application as well as an application framework with concerns such as:

## Sample authentication

The login screen is prefilled with dummy values so the starter app can be launched
without connecting to a real backend. The authentication code in
`source/api/Authentication.brs` is stubbed to accept that sample login and return a
dummy authenticated session.

Before using this project for a real channel, replace the sample login values and
stubbed authentication response with the authentication flow your app needs. Wire
the login, token validation, logout behavior, and session payload shape to match
your own API.

## Fork renaming checklist

If you fork this repository for your own Roku channel, replace the starter-kit
names in these places:

- `manifest`: `title=Roku Starter Kit`
- `package.json`: `"name": "roku-starter-kit"`
- `package.json`: `"description": "A starter kit for building a Roku application."`
- `.vscode/launch.json`: `"name": "Roku Starter App"`
- `scripts/deploy.mjs`: `const outFile = 'roku-starter-kit'`
- `scripts/logviewer.mjs`: the console message that references the Roku Starter
  Kit VS Code debug configuration.
- `scripts/package.mjs`: the package filename template
  `roku.starter.kit.<major>.<minor>.<build>`.
- `source/store/AuthStore.brs`: the `ROKU_STARTER_APP` registry section name.
- `source/store/SettingsStore.brs`: the `ROKU_STARTER_APP` registry section name.

Use an app-specific registry section name before shipping so auth and settings
data for your fork do not collide with another app based on this starter kit.

## BrightScript vs BrighterScript

This sample app is written in BrightScript rather than BrighterScript.
BrightScript is Roku's native scripting language for SceneGraph channels.
BrighterScript is a superset and toolchain that adds conveniences such as
stronger typing, classes, namespaces, imports, and other language features that
compile back down to BrightScript for Roku devices.

This repo intentionally sticks with BrightScript so the code stays close
to Roku's platform concepts and does not hide SceneGraph or BrightScript patterns
behind extra abstractions. BrighterScript can still be a good option for teams
that want stronger tooling or a more structured application style, and this
starter kit could be modified to use it.

# Developer Commands

This project uses npm scripts for local build, package, deploy, and log-viewer
workflows.

## VS Code Extensions

Install the **RokuCommunity BrightScript Language** extension:

```
rokucommunity.brightscript
```

This extension is required for VS Code debug mode. The workspace debug config uses
`"type": "brightscript"`, which is provided by the RokuCommunity extension.

Optional helper extensions:

- `alicebeckett.brightscriptcomment`: comment-formatting helper only; not required
  for launch/debug.
- `redhat.vscode-xml`: XML formatting for SceneGraph files; useful but not
  required for launch/debug.

## Setup

Install dependencies before running the scripts:

```
npm install
```

For Roku deploys, copy `rokudeploy.example.json` to `rokudeploy.json` and fill in
your Roku device host and developer password. `rokudeploy.json` is ignored by git.

## Scripts

`npm run clean`

Deletes generated build output. This removes `build/` and `out/` using `rimraf`, a cross-platform delete tool that
works reliably on Windows.

`npm run validate`

Runs the BrightScript compiler validation step. This checks the Roku app from the repo root and stages compiler output under `build/staging`.

`npm run increment-build-version`

Increments `build_version` in `manifest` by 1. This command is run automatically by `npm run build`, `npm run package`, and `npm run deploy`.

`npm run build`

Increments `build_version` in `manifest`, cleans generated output, and runs validation. Use `npm run validate` instead when you want a non-mutating validation pass.

`npm run package`

Increments `build_version`, cleans, validates, and creates a Roku package.

The package script uses `scripts/package.mjs` and writes the packaged channel to a versioned zip using the manifest version:

`out/roku-starter-kit.<major_version>.<minor_version>.<build_version>.zip`

`npm run deploy`

Increments `build_version`, validates, and deploys the app to the Roku device configured in `rokudeploy.json`. Use this when you want to push the current app to a physical Roku device.

`npm run logviewer`

Starts the local browser-based Roku log viewer. This was created to give a better view into the Roku output logs than what is presented in VS Code. The entirety of the log viewer is in the `/scripts/logviewer.mjs` file and uses node.js to serve the log viewer app run a web server.

The viewer serves a local web UI, watches `logs/rokuDevice.log`, and displays Roku
log output in real time. Start the VS Code Roku app debug configuration to make the
RokuCommunity extension write device output to that log file.

For direct Roku socket mode, run:

`node ./scripts/logs.mjs --socket`

Socket mode connects directly to the Roku debug console on port `8085`, so it
cannot run at the same time as the VS Code Roku debugger.

## Roku Logs And The Browser Log Viewer

When the RokuCommunity extension starts the VS Code Roku app debug configuration,
it connects to the Roku debug console/log stream on telnet port `8085`. VS Code
then displays that device output in the **BrightScript Log** output window.

Roku only allows one active console/debug connection on port `8085`. Because VS
Code already owns that connection during debugging, the browser log viewer cannot
also connect directly to the Roku telnet log stream at the same time.

To support debugging and the browser log viewer together, `.vscode/launch.json`
enables RokuCommunity file logging. VS Code writes the device log to:

```text
logs/rokuDevice.log
```

The browser log viewer watches that file instead of connecting directly to port
`8085`. This lets VS Code keep the debugger connection while the browser UI
renders the same log output in a custom view.
