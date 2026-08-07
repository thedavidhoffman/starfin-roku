# Playback Chaos Monkey

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
