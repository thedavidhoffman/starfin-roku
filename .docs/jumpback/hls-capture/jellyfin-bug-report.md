# Official Roku client: HLS playback repeats the ending; successive segments contain identical video (Jellyfin 12 / FFmpeg 8.1.2)

## Description

An MP4 movie repeats footage at the ending when played through the official Jellyfin Roku client using HLS with copied H.264 video and stereo MP3 audio conversion. Saved server-generated TS files show that later segment numbers contain identical ordered video packets and matching presentation timestamps from earlier segments.

All reproduction details and packet comparisons below refer to one official-client session on September 11, 2026. Playback was paused after the visible replay occurred.

## Environment and media

- Server: Jellyfin 12 on Windows; exact Windows edition/build not recorded.
- FFmpeg: 8.1.2-Jellyfin, confirmed in server logs.
- Client: official Jellyfin Roku client. Exact client version, Roku model, and Roku OS version still need recording.
- Source: MP4, H.264 High, 1280x502, approximately 23.976 fps; AAC LC 5.1, 48 kHz.
- Runtime: 76214547880 ticks = 7621.454788 seconds (2:07:01.45).
- Delivery: MPEG-TS HLS, H.264 video copy, stereo MP3 audio conversion (`libmp3lame -ac 2 -ab 256000`). No subtitle stream mapped in FFmpeg.
- FFmpeg segment target: `-hls_time 6`.
- Server `encoding.xml`: `AllowOnDemandMetadataBasedKeyframeExtractionForExtensions` contains only `mkv`. No configuration workaround was applied.

## Reproduction

1. Play the affected MP4 in the official Jellyfin Roku client with the delivery path above.
2. Seek near the ending and resume. The resulting FFmpeg job sought to 2:03:48.500; the exact client seek target was not recorded.
3. Let playback reach the ending. Earlier ending footage plays again.

Expected: the ending plays once and playback finishes.

Actual: the viewer sees repeated ending footage, and the server generates duplicate video under later segment numbers.

## Server job sequence

All four jobs used output prefix `7e6ad766012374ef0181d7de51435e01`. Times are EDT on September 11, 2026.

| FFmpeg log time | Requested input seek | Starting segment | Relevant output |
|---|---|---|---|
| 14:51:51 | Beginning | 0 | Initial playback job |
| 14:53:37 | 2:03:48.500 | 1238 | Generates through 1264, including the ending |
| 14:54:39 | 2:06:30.500 | 1265 | Generates 1265-1269, repeating earlier video |
| 14:56:15 | 2:06:56.454 | 1270 | Generates 1270-1271, repeating the ending again |

Jobs may run ahead of visible playback because of buffering. Their start times are not necessarily the moment the viewer sees the jump.

## Packet-level evidence

A cache watcher preserved TS files and successive FFmpeg playlists before cleanup. Capture began after the seek job started; existing ending segments numbered 1240 and above and subsequent files were saved.

For each saved TS file, FFprobe extracted video packet SHA-256 payload hashes and timestamps:

```text
ffprobe -v error -select_streams v:0 -show_entries packet=pts_time,dts_time,duration_time,data_hash -show_data_hash sha256 -of json segment.ts
```

Every video packet payload in each later segment matches the corresponding earlier segment, in the same order. First presentation timestamps also match:

| Earlier segment | Later segment | Identical ordered video packets | First PTS in both (seconds) |
|---|---|---|---|
| 1260 | 1265 | 249 / 249 | 7594.542878 |
| 1261 | 1266 | 249 / 249 | 7604.928267 |
| 1262 | 1267 | 128 / 128 | 7615.313644 |
| 1263 | 1268 | 250 / 250 | 7620.652322 |
| 1264 | 1269 | 9 / 9 | 7631.079411 |
| 1263 | 1270 | 250 / 250 | 7620.652322 |
| 1264 | 1271 | 9 / 9 | 7631.079411 |

These compare video packet payloads, not whole-file hashes. Transport headers and audio need not match. PTS values are output transport timestamps, not assumed to equal source-file playback positions.

Saved playlists declare 36.911934 seconds for segments 1265-1269, and 10.802489 seconds for 1270-1271. Approximately 47.7 seconds of video is duplicated in generated output; this is not a measurement of exactly how much footage Roku displayed.

## Suspected mechanism

The source trace below explains the observed generation pattern, but the original HTTP playlist and segment-request sequence were not captured:

1. In [DynamicHlsPlaylistGenerator at v12.0](https://github.com/jellyfin/jellyfin/blob/v12.0/src/Jellyfin.MediaEncoding.Hls/Playlist/DynamicHlsPlaylistGenerator.cs), this MP4 is excluded by the configured extraction extension list. It falls back to equal-length playlist entries with cumulative `runtimeTicks` in segment URLs.
2. Saved FFmpeg playlists contain actual segment durations around 10.385 seconds despite the six-second target. The seek job reaches the ending by segment 1264.
3. In [DynamicHlsController at v12.0](https://github.com/jellyfin/jellyfin/blob/v12.0/Jellyfin.Api/Controllers/DynamicHlsController.cs), a missing segment with no active transcoding index can start another job using `StartTimeTicks = CurrentRuntimeTicks`. An exited job has no active index.
4. On the calculated six-second timeline, segment 1265 corresponds to 7590 seconds (2:06:30). This is consistent with the next job's input seek and the duplicated ending video.

## Evidence limits and workaround status

- Saved playlists are FFmpeg cache playlists, not captured HTTP responses to Roku.
- Roku's HTTP segment-request history and client debug log were not captured for this session.
- Duplicate generated video is confirmed; the precise request chain causing regeneration is inferred from source and server logs.
- A subsequent keyframe-extraction/configuration experiment is documented below; it did not eliminate generated duplicate video.
- A redistributable minimal reproduction file has not yet been prepared.

## Follow-up: cached keyframes plus MP4 configuration

After the baseline reproduction, the keyframe extraction task was run, `mp4` was added alongside `mkv` in `AllowOnDemandMetadataBasedKeyframeExtractionForExtensions`, and Jellyfin was restarted. The official Roku client was tested again with video copy and stereo MP3 audio conversion.

The user reported that the usual large replay did not occur, but was uncertain whether a smaller replay occurred. Saved files confirm that duplicated ending video remains:

| FFmpeg log time (EDT) | Input seek | Starting segment |
|---|---|---|
| 15:42:10 | Beginning | 0 |
| 15:43:59 | 2:04:28.426 | 991 |
| 15:44:06 | 2:06:56.454 | 1011 |

The seek run's cached playlist ends at segment 1010. The next run generates 1011-1012. Video packet comparisons confirm that 1011 repeats all 250 packets from 1009, and 1012 repeats all 9 packets from 1010, in the same order and with matching first PTS values (7620.652322 and 7631.079411 seconds respectively).

The duplicated segments span approximately 10.802489 seconds according to the saved playlists. This measures generated duplicate video, not confirmed visible replay duration. Segment numbering changed substantially, but the original HTTP playlist remains uncaptured. The configuration experiment therefore does not establish a complete workaround, and the equal-length fallback alone does not explain the remaining duplication.

Follow-up FFmpeg logs, cache playlists, TS files, and packet JSON comparisons are preserved separately from the baseline capture.

## Additional source lead: final-segment seek clamp (unconfirmed)

Read-only inspection of a local Jellyfin checkout identified as `v12.0-rc7-121-g1d7b6d9784` found that `EncodingHelper.GetFastSeekCommandLineParameter` adds 0.5 seconds for HLS video-copy seeks, then clamps the result to no later than `RunTimeTicks - 5 seconds`:

```csharp
var seekTick = isHlsRemuxing ? time + 5000000L : time;
if (maxTime > 0)
{
    seekTick = Math.Clamp(seekTick, 0, Math.Max(maxTime - 50000000L, 0));
}
```

Source: [EncodingHelper.cs at the inspected revision](https://github.com/jellyfin/jellyfin/blob/1d7b6d9784/MediaBrowser.Controller/MediaEncoding/EncodingHelper.cs). This checkout has not been established as identical to the installed server binary.

FFprobe inspection of the source MP4 found its final keyframe at 7621.079413 seconds, shortly before the 7621.454788-second ending. The clamp limits an input seek to 7616.454788 seconds, matching the `02:06:56.454` seek in the final FFmpeg restart logs. Seeking before that final keyframe while copying video is consistent with returning to earlier footage.

This is a possible contributor to the remaining approximately 10.8 seconds of duplicated output after keyframe extraction and the MP4 configuration change. It does **not** explain why the playlist requests another segment after the preceding FFmpeg job has already generated the ending. The playlist-to-generated-segment mismatch remains the central unresolved question. Removing the clamp alone is not proposed as a validated fix; its code comment says it avoids near-EOF muxer errors.

No server-code changes, custom builds, or regression-test validation have been performed. The configuration experiment did not fully resolve generated duplication. These observations are provided as investigation leads for maintainers, not a confirmed root cause or patch.

## Comparison: web Direct Play

The same title played without the observed ending replay in Jellyfin Web. On a repeat check, the web player reported `Html Video Player (Direct playing)`.

This is a different delivery path: Direct Play bypasses the FFmpeg HLS segmentation used in the affected official Roku session. The successful web result does not establish that HLS playback is unaffected in the web client. The reported issue is specifically ending replay during HLS video-copy playback on the official Roku client; web Direct Play was unaffected in the user's test.

## Related report

[jellyfin/jellyfin#2067](https://github.com/jellyfin/jellyfin/issues/2067) is a closed historical report describing similar ending replay and additional FFmpeg segment ranges after the ending. It may be related; a shared root cause has not been established.

## Evidence available

Preserved from this official-client session: four FFmpeg logs (14:51:51, 14:53:37, 14:54:39, 14:56:15), timestamped TS copies, successive cache playlists, and packet JSON results for segments 1260-1271. Raw media is not included in this draft.

Can maintainers confirm whether the equal-length fallback can advertise more segment indices than video-copy FFmpeg generates, causing the missing-segment handler to regenerate ending footage? What is the supported correction for MP4 video-copy HLS?
