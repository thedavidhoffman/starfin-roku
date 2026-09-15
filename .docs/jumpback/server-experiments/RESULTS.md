# HLS jumpback candidate fix — September 13, 2026

**Superseded:** The earlier-processing approach documented below was rejected for seek latency and has been removed from the patch. See [DIRECT-RESULTS.md](DIRECT-RESULTS.md) for the replacement and its measured first-segment readiness.

The original captures in `C:\dev\starfin-roku\out\hls-capture` were only read. All new experiment output is in this directory. The running Jellyfin service, configuration, and original movie were not changed.

## What changed

For dynamic video-copy HLS with available, enabled keyframe data, the server now checks whether restarting at the requested boundary reproduces every remaining advertised boundary. If it does not, it selects the nearest earlier boundary that does. The FFmpeg starting sequence and input position both follow that selection; the server still waits for and serves the originally requested segment.

The input seek is bounded inside that starting keyframe's interval, before the next keyframe and video EOF. It is formatted at millisecond precision strictly after the boundary. EncodingHelper bypasses its five-second EOF clamp only for this validated video-copy seek. Other streaming paths retain their existing seek behavior.

This preserves the current HLS muxer, segment format, playlist URLs, and advertised segment schedule. No FFmpeg modifications are required.

## Actual-media results

Environment: installed Jellyfin assembly reports 12.0.0; installed FFmpeg reports 8.1.2-Jellyfin. Patch compiled against checkout `1d7b6d9784` (`v12.0-rc7-121-g1d7b6d9784`), not injected into the installed release. A portable .NET 10.0.401 SDK was installed under the workspace's ignored `dotnet` directory to run tests.

The isolated harness calls the modified server assembly to compute all 1,012 restart plans from the preserved source keyframe timestamps. `restart-plans.json` records the results. `verify-restarts.ps1` then runs the installed FFmpeg against the original movie using selected plans, with copied H.264 and stereo MP3 conversion.

| Requested segment | Generated from | Segments generated through EOF | Video packets | Result |
| --- | --- | --- | --- | --- |
| 991 | 988 | 24, ending at 1011 | 4,237 | Every boundary matches |
| 1009 | 1008 | 4, ending at 1011 | 636 | Every boundary matches |
| 1011 | 1011 | 1 | 9 | Correct final video only |

All three cases passed with both MPEG-TS and fMP4. Each segment's duration and first video PTS match the computed playlist to within 1 ms, accounting for the MPEG-TS transport timestamp offset. Overlapping segments 1009–1011 have identical ordered video payload hashes and PTS across the runs starting at 988 and 1008, independently for both containers. See `verification-results.json` and `packet-consistency.json`.

The original failing restart at 991 merged the advertised 3.420-second segment with the following segment. Restarting at 988 preserves that cut. Direct EOF experiments also showed that seeking to 7616.454 or the rounded-down 7621.079 seconds returns the preceding 250 video packets; seeking inside the final keyframe interval returns only the final nine.

## Tests

- Playlist tests: 30 passed, including missing/stale keyframe inputs, sparse and dense keyframes, EOF, sub-millisecond intervals, and deterministic irregular schedules tested at every possible seek.
- EncodingHelper tests: 28 passed, including the validated EOF seek and preservation of other paths' offset/clamp behavior.
- DynamicHlsController tests: 10 passed, including existing active-request replacement coordination.
- `git diff --check`: passed.

These are focused unit tests plus isolated FFmpeg integration experiments. No end-to-end HTTP/Roku playback test of a patched server was performed. Audio continuity, subtitle behavior, and other media/container combinations need playback validation; the packet comparisons above cover video.

## Cost and remaining limitations

- The patch requires a keyframe-based playlist. It respects the existing extraction extension allowlist and cache behavior. The original equal-length fallback without usable keyframe data remains unfixed; keep the MP4 keyframe configuration and extracted keyframe data for this title.
- Preserving the whole remaining schedule sometimes requires substantial preceding media to be regenerated. Request 991 adds 23.190 seconds of media processing. The largest preceding span among this movie's 1,012 plans is 905.656 seconds for request 726, restarting at 576. An isolated run processing that span plus 30 seconds completed in 12.791 wall-clock seconds on this machine and generated the requested segment successfully. This is a processing benchmark, not a measurement of Roku seek latency.
- This conservative implementation can fall back to regenerating from the beginning when no later compatible boundary exists. The cost needs acceptance testing on the target hardware; a general low-latency solution may require explicit cut-schedule support in FFmpeg instead.
- Use a fresh playback session when validating a patched build so old, incorrectly numbered cached segments cannot contaminate the result. Retain the original server installation for rollback. No deployment was performed.

## Reproducing the isolated checks

From `C:\dev\jellyfin`, run the workspace `dotnet\dotnet.exe` with the harness project in this directory and pass the preserved `source-keyframes.json` path plus a destination `restart-plans.json` path. The harness reads source evidence without modifying it. Run `verify-restarts.ps1` with a fresh `-OutputRoot` directory; its existing output directories are deliberately not overwritten. The script defaults to the original movie's local path and installed FFmpeg/FFprobe paths.
