# HLS replay capture

Captured September 11, 2026, during the reported Jellyfin 12 / Starfin reproduction.

ffprobe SHA256 video packet comparisons establish identical ordered payloads and matching first presentation timestamps:

| Earlier segment | Later segment | Matching packets | First PTS (both) |
|---|---|---|---|
|1260|1265|249 of 249|7594.542878|
|1261|1266|249 of 249|7604.928267|
|1262|1267|128 of 128|7615.313644|
|1263|1268|250 of 250|7620.652322|
|1264|1269|9 of 9|7631.079411|
|1263|1270|250 of 250|7620.652322|
|1264|1271|9 of 9|7631.079411|

Cached FFmpeg playlists declare a combined 36.911934 seconds for segments 1265-1269, all duplicating earlier video. Segments 1270-1271 duplicate another 10.802489 seconds. Combined duplicated video duration: approximately 47.714423 seconds. This is generated content, not a measurement of footage actually displayed by Roku.

Evidence: timestamped TS and cache M3U8 copies, packets-*.json (ffprobe video packet payload hashes and timestamps), matching FFmpeg logs.

The actual HTTP playlist response and Roku HTTP request history were not captured. The generated files prove duplicated video under successive segment numbers; they do not alone establish the exact HTTP request sequence or why the server selected those numbers. No production code or server settings were changed.

## Jellyfin 12 source trace

Read-only inspection of the Windows server encoding.xml found AllowOnDemandMetadataBasedKeyframeExtractionForExtensions contains only mkv. The movie path ends in .mp4.

In Jellyfin v12.0 DynamicHlsPlaylistGenerator.CreateMainPlaylist, a remux uses extracted keyframes only if TryExtractKeyframes succeeds. TryExtractKeyframes immediately rejects extensions outside the configured list. Consequently this MP4 follows ComputeEqualLengthSegments. The generated segment URLs carry cumulative runtimeTicks and actualSegmentLengthTicks from that calculated timeline.

Captured FFmpeg playlist durations differ: for example segments 1260 and 1261 each span approximately 10.385 seconds, while the configured desired length is six seconds. FFmpeg reaches the source ending at segment 1264 in the seek run.

DynamicHlsController returns existing segments directly. For a missing segment and no active transcoding index (including an exited FFmpeg job), it starts another job with StartTimeTicks = CurrentRuntimeTicks and the requested segment number. Segment 1265 on the equal-length timeline is 7590 seconds (2:06:30), consistent with the FFmpeg restart log near that time. This explains generation of repeated ending footage under the next numbers.

Starfin source/DeviceCapabilities.bs, jellyfin-roku source/utils/deviceCapabilities.bs, and Moonfin/Roku source/utils/deviceCapabilities.bs all request MinSegments=1, SegmentLength=6, BreakOnNonKeyFrames=false. This comparison is limited to the relevant segmentation settings, not complete client equivalence.

Sources inspected: Jellyfin v12.0 src/Jellyfin.MediaEncoding.Hls/Playlist/DynamicHlsPlaylistGenerator.cs and Jellyfin.Api/Controllers/DynamicHlsController.cs. Copies are in the parent capture directory. Source/config analysis strongly explains the observed generated sequence; the original HTTP response remains uncaptured. No settings changed. Adding mp4 to the extraction list is not established as a fix: supported metadata extractors must be checked first.
