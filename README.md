[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/thedavidhoffman)

This project is open source, and contributions are welcome. If you're interested in improving this app, please consider opening an issue or pull request here rather than creating a separate forked version. Keeping development centered in this repository helps avoid duplicate work, makes improvements easier for everyone to find, and gives the community a single place to collaborate.

Forks are part of open source but if your goal is to fix bugs, add features, or improve compatibility, contributing those changes back here is greatly appreciated.

# INTRODUCTION

I've been running Plex for well over 10+ years and with the direction that Plex is heading, I wanted to make a move. I tried Emby for 3 months and the Roku experience didn't have the level of polish I'm used to with Plex. Jellyfin was never an option for me because their Roku client is... well... let's just say, not great. Sure, there's Moonfin, and that's better, and I'm by no means taking a stab at Moonfin, but it's just not for me.

So with the help of AI, and my senior software developer skills guiding it, I created Starfin. Now if anything with the UI sucks, there's no one to blame but me. As soon as this project had legs enough to stand on its own, browse and play media, I started using/testing it as my daily driver. And I soon found that I was leaving Plex behind now that I had a Jellyfin Roku client that aligned with my wants, needs, and desires. For any AI haters out there, you do your thing, I'll do mine :) But as a well seasoned senior software engineer, AI helps accelerate what you can accomplish. This project took about 6 weeks of HEAVY work, testing, guiding the architecture, the UI, and so on. Before AI, this project would have taken months, if not a year or longer (coding it in my spare time).

OK, now that all my jib jab is out of the way, I present to you `Starfin`, a modern Jellyfin client for Roku devices.

# CAVEATS
- I've tested a library with around 2,000 movies and performance is great. I don't know how this thing will hold up with a library of 10,000 movies. That being said, if anyone out there tries this app and has a huge library, let me know how it goes.

# CODE FOUNDATIONS

The code for this app is NOT a fork of the Jellyfin Roku code repo. IMHO the Jellyfin Roku code base isn't a good starting point as the code isn't structured very well. But the Jellyfin Roku code is an excellent reference for how to do things. Instead I used all of my learnings from the [ABSTV Roku app](https://github.com/thedavidhoffman/abs-tv-roku) I build as a Roku client for [Audiobookshelf](https://www.audiobookshelf.org/) as a foundation for this app (stripping it down to its bare essentials without any Audiobookshelf stuff as a starting base).

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

## Playback Chaos Monkey

Playback Chaos Monkey is a development-only stress tool for exercising the
video player's bounded recovery behavior on a reliable server and network. In
VS Code, select the `Starfin — Playback Chaos Monkey` launch profile instead of
the normal `Starfin` profile. The special profile enables the manifest
`playbackChaosMonkey` compile constant and activates the tool automatically;
there is no in-app setting.

While an on-demand video is playing, Chaos Monkey waits a random 30–60 seconds
and then injects a video error, playback-info failure, buffering stall, or
buffering-at-100-percent condition through the real recovery path. Injection is
postponed while seeking, buffering, changing streams, showing an overlay, or
already recovering. Follow-up failures are capped to the recovery attempts still
available, allowing long-running playback tests without intentionally exhausting
the player.

An on-screen badge starts at `CHAOS MONKEY 0` and increments for every injected
incident. Search `logs/rokuDevice.log` for `Playback Chaos Monkey` to see when the
tool is enabled, scheduled, injecting failures, continuing an incident,
stabilizing, or exhausting recovery. Logs include the effective playback mode
and preserved position but do not include playback URLs or tokens.

The checked-in manifest defaults `playbackChaosMonkey` to `false`, so normal VS
Code launches and release packages compile the feature out.

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

`out/starfin.<major_version>.<minor_version>.<build_version>.zip`

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
