# Direct-start HLS restart fix

The earlier-processing implementation has been replaced. The new code never selects an earlier segment or earlier playlist position to compensate for mismatched cuts. Original captures, source media, installed server files, and live configuration remain unchanged.

## Behavior

The playlist generator computes a range of FFmpeg `hls_time` values that reproduce all remaining advertised boundaries starting at the requested segment. Every selected and skipped keyframe contributes a constraint. FFmpeg compares its nth local cut against n times this duration; adjusting the duration can preserve the cuts without reading earlier media.

The code retains the original duration when valid and otherwise selects a value inside the feasible range at FFmpeg's microsecond precision. The actual advertised segment lengths and URLs remain unchanged. EncodingHelper still receives a validated seek inside the requested keyframe interval, preventing the five-second clamp from seeking into preceding footage near EOF.

All 1,012 segment positions in the affected movie have a valid direct-start plan, computed using the modified server assembly. None requires earlier processing. Plans are saved in `direct-restart-plans.json`.

## First-segment timing

Measured from FFmpeg launch until the requested segment is complete: detected by the next segment opening, or successful process exit for the final segment. Runs use the original movie, installed FFmpeg 8.1.2-Jellyfin, video copy, and stereo MP3 conversion. Input was limited to 30 seconds to measure startup without processing the rest of the movie. This is **not** an end-to-end Roku or HTTP latency measurement.

| Requested segment | MPEG-TS | fMP4 |
| --- | --- | --- |
| 726, formerly the worst earlier-processing case | 0.296 s | 0.295 s |
| 991, original failing restart | 0.253 s | 0.262 s |
| 1011, final segment | 0.101 s | 0.103 s |

No preceding media was processed in any of these runs. See `direct-latency-results.json` and `measure-direct-latency.ps1`.

## Correctness checks

- Eight complete-to-EOF checks passed: direct restarts at 991, 992, 1009, and 1011 in both MPEG-TS and fMP4. Every generated duration and first video PTS matches the advertised schedule within 1 ms, accounting for the MPEG-TS transport offset. Every run ends at segment 1011; the direct final restart contains only the correct nine video packets.
- Overlapping segments 992 and 1009–1011 have identical ordered video hashes and PTS between runs starting directly at different requested segments, independently in both containers.
- A separate full-to-EOF MPEG-TS run starting directly at 726 also matched all 286 remaining segment durations.
- Focused tests: 31 playlist tests, 28 EncodingHelper tests, and 13 DynamicHlsController tests passed. Coverage includes an incompatible schedule that must not trigger earlier processing, irregular schedules, sparse/dense keyframes, bounded EOF seeking, and culture-invariant microsecond duration formatting.
- `git diff --check` passed.

See `direct-validation/verification-results.json`, `direct-validation/packet-consistency.json`, `direct-retiming-results.json`, and the `retimed-*-tests*.log` files.

## Remaining limits

This is a fix for keyframe-based playlists with a feasible duration range, not a universal solution for all HLS sources. Some keyframe schedules cannot preserve every cut with a single constant HLS duration. Those return no override and keep existing behavior, which may still exhibit the original mismatch. They never fall back to the rejected earlier-processing approach. The equal-length playlist fallback without usable keyframe data is also unchanged.

The installed FFmpeg experiments validate the affected movie's video segmentation. A patched server has not been deployed or exercised through Roku. Audio continuity, subtitles, HTTP behavior, and other media still need end-to-end validation. Existing MP4 keyframe data and configuration are required for this title.

The historical `RESULTS.md` describes the rejected prototype, not the current patch.
