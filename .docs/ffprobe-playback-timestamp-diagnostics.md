# FFprobe Playback Timestamp Diagnostics

This note documents how to inspect media files that repeat or jump backward
during Jellyfin playback on Roku. The current investigation involves HEVC
Main 10 video in MP4 files that Jellyfin dynamically remuxes into MPEG-TS HLS.
A full video transcode avoids the symptom, which makes unusual source
timestamps or keyframe placement worth investigating.

Run the commands against both:

- A file that has exhibited the playback problem.
- A similar file that consistently plays correctly.

Comparing the two results is more useful than inspecting the problematic file
in isolation.

## Prerequisite

`ffprobe` is included with FFmpeg. Confirm that it is available:

```text
ffprobe -version
```

Run the commands on the original media file, not a Jellyfin-generated HLS
segment. Replace `episode.mp4` with the full path to the file.

## Inspect File And Stream Timing

```text
ffprobe -v error -show_entries format=start_time,duration -show_entries stream=index,codec_name,avg_frame_rate,r_frame_rate,start_time,duration,time_base -of json "episode.mp4"
```

This command provides a compact overview of the container and individual
stream timelines without printing all media metadata.

The fields tell us:

- `format.start_time`: The starting timestamp reported by the MP4 container.
  This is normally zero or very close to zero. A substantial positive or
  negative value can affect seeking and remuxing.
- `format.duration`: The duration reported by the container.
- `stream.start_time`: The starting timestamp for each video, audio, or
  subtitle stream. Different video and audio start times can reveal an offset
  that Jellyfin must preserve or correct.
- `stream.duration`: The duration of each stream. A material difference between
  the video, audio, and container durations can explain why playback continues
  past the displayed duration or finishes early.
- `time_base`: The unit used for that stream's timestamps. For example,
  `1/90000` means each timestamp tick represents 1/90000 of a second.
- `avg_frame_rate`: The average frame rate calculated over the stream.
- `r_frame_rate`: FFmpeg's estimated base or nominal frame rate.

For the affected Blue Bloods files, the server logs report approximately
23.976 fps. That is a normal Blu-ray frame rate and does not, by itself,
indicate a French or PAL frame-rate conversion problem. PAL-derived material
would more commonly report 25 or 50 fps.

Look for:

- A non-zero container or video start time.
- Video and audio streams with different start times.
- Stream durations that differ materially from the container duration.
- `avg_frame_rate` and `r_frame_rate` values that disagree unexpectedly.
- Differences that occur only in the problematic files.

## Inspect Video Packet Timestamps And Keyframes

```text
ffprobe -v error -select_streams v:0 -show_entries packet=pts_time,dts_time,duration_time,flags -of csv "episode.mp4"
```

This command prints one row for every packet in the first video stream. Its
output can be large, so redirect it to a file when necessary:

```text
ffprobe -v error -select_streams v:0 -show_entries packet=pts_time,dts_time,duration_time,flags -of csv "episode.mp4" > video-packets.csv
```

The fields tell us:

- `pts_time`: Presentation timestamp - the time at which the decoded frame should
  be displayed.
- `dts_time`: Decode timestamp - the time at which the packet must be decoded.
  DTS can differ from PTS because codecs such as HEVC reorder frames.
- `duration_time`: The packet's expected duration.
- `flags`: Packet attributes. A `K` identifies a keyframe.

Look for:

- PTS values that move backward unexpectedly.
- Large forward gaps between adjacent PTS values.
- Missing, negative, or otherwise unusual timestamps.
- Abrupt changes in packet duration.
- Very long intervals between packets marked with `K`.
- A discontinuity near the point where playback visibly jumps.

PTS and DTS do not need to be identical, and DTS may appear out of presentation
order with codecs that use frame reordering. The important questions are
whether the presentation timeline has unexplained gaps or regressions and
whether the problematic file differs from a known-good encode.

## Optional Keyframe-Only View

To make keyframe spacing easier to inspect, show only video packets marked as
keyframes:

```text
ffprobe -v error -select_streams v:0 -skip_frame nokey -show_entries frame=best_effort_timestamp_time,pkt_duration_time,key_frame -of csv "episode.mp4"
```

This helps determine whether keyframes occur at regular intervals. Sparse or
irregular keyframes can make Jellyfin's `-ss` seeking and six-second HLS
segmentation begin earlier than requested or produce unusually long segments
when the video is copied instead of encoded.

## How The Results Relate To The Roku Problem

Jellyfin currently invokes FFmpeg with source seeking, timestamp preservation,
and copied HEVC video:

```text
-ss <start> -copyts -start_at_zero -codec:v copy -f hls
```

That workflow preserves much of the source video's timing and keyframe
structure while repackaging it as MPEG-TS HLS. If the source has an unusual
edit timeline, timestamp discontinuity, or keyframe layout, the remuxed stream
may expose a Jellyfin, FFmpeg, or Roku playback defect.

The results can support the following conclusions:

- Normal timestamps and regular keyframes would weaken the malformed-rip
  theory and point more strongly toward Jellyfin or Roku remux handling.
- Timestamp gaps, regressions, or stream-duration mismatches would support the
  theory that this encode triggers the problem.
- Irregular or sparse keyframes would explain why dynamic HLS seeking and
  segment boundaries behave differently for this show.
- Similar anomalies in a known-good file would mean the anomaly alone is not
  sufficient to explain the symptom.

## Testing The Video Playback Options

For the playback issues described in this document, test **Force Transcode
(Remux Disabled)** first.

This option forces Jellyfin to re-encode the video and create new keyframes and
HLS segments while potentially normalizing timing behavior. It is the option
most likely to resolve playback stalls, broken seeking, timing errors, or files
that begin playback incorrectly.

Use the following testing order:

1. **Force Transcode (Remux Disabled)** provides the strongest compatibility
   test.
2. **Force Transcode (Allow Remux)** determines whether repackaging alone fixes
   the problem while using less server processing.
3. **Direct Play** provides a baseline using the original file without
   conversion or repackaging.

If Direct Play reproduces the problem while either forced option works, the
original file, container, or stream structure is likely triggering the issue.

If Force Transcode (Remux Disabled) works but Force Transcode (Allow Remux)
does not, the problem is probably in the source video stream or its timestamp
or keyframe structure, rather than only in the container.

These commands cannot prove what Roku displayed. They inspect the source file,
not the client's decoded output. Correlating a timestamp anomaly with the
visible jump position, or comparing it with Starfish's playback-position
diagnostics—provides the strongest evidence.
