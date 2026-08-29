# Video Playback Options

The Video toolbar provides four playback modes for the current movie or
episode. The selected mode remains active while the user stays on that title's
MediaShell page, including after playback stops and returns to the page. It is
retained during same-title audio or subtitle restarts, but it is not saved as
an application preference or carried into the next queued title. Loading a
different title resets the page to Automatic playback.

The same options are available from the Video button in the in-player controls.
Changing the mode there restarts the current title at its current position and
retains the selected audio and subtitle tracks. The selected mode is reflected
on the title's MediaShell page when playback stops.

Subtitle burn-in is requested only when a real subtitle stream is selected.
Restarting a title with subtitles Off, including a switch to either Force
Transcode mode, preserves the Off selection and does not allow the server to
introduce or burn in a subtitle track.

## Playback Mode Matrix

| Option | Direct Play | Direct Stream | Transcoding | Video stream copy | Audio stream copy |
| --- | --- | --- | --- | --- | --- |
| Automatic | Enabled | Enabled | Enabled | Allowed | Allowed |
| Automatic (Remux Disabled) | Enabled | Disabled | Enabled | Disabled | Allowed |
| Force Transcode (Allow Remux) | Disabled | Enabled | Enabled | Allowed | Allowed |
| Force Transcode (Remux Disabled) | Disabled | Disabled | Enabled | Disabled | Allowed |

Automatic is the normal playback mode. It allows Jellyfin to choose Direct
Play, Direct Stream/remuxing, or transcoding based on the file, selected audio
and subtitle tracks, device capabilities, and network limits. It also preserves
the app's existing compatibility handling for selected streams.

## Automatic With Remux Disabled

Automatic (Remux Disabled) sends Jellyfin the following controls:

```text
EnableDirectPlay=true
EnableDirectStream=false
EnableTranscoding=true
AllowVideoStreamCopy=false
AllowAudioStreamCopy=true
```

These are the normal request controls when the selected audio is compatible
and no non-default audio stream requires explicit selection. The app disables
Direct Play when its Roku capability check determines that selected
multichannel AAC must be converted, or when a non-default audio stream is
selected. Direct Stream and video stream copying remain disabled in either
case.

Jellyfin may Direct Play the original file when the complete file and selected
tracks are compatible. If Direct Play is unavailable, Jellyfin must provide a
transcoding stream and may not copy the video stream into it. This preserves
original quality and avoids server processing when Direct Play is possible,
while avoiding the video-remux path when fallback conversion is required.

Audio stream copying remains allowed. Jellyfin may copy compatible audio or
encode incompatible audio according to the Roku device profile.

## Force Transcode With Remux Allowed

Force Transcode (Allow Remux) sends:

```text
EnableDirectPlay=false
EnableDirectStream=true
EnableTranscoding=true
AllowVideoStreamCopy=true
AllowAudioStreamCopy=true
```

Jellyfin must not Direct Play the original file. It may repackage compatible
streams into HLS without encoding them and may transcode individual
incompatible streams.

For example, Jellyfin may copy compatible HEVC video while converting
multichannel AAC audio to stereo AAC:

```text
-codec:v:0 copy
-codec:a:0 libfdk_aac -ac 2
```

This is the expected result for this mode.

## Force Transcode With Remux Disabled

Force Transcode (Remux Disabled) sends:

```text
EnableDirectPlay=false
EnableDirectStream=false
EnableTranscoding=true
AllowVideoStreamCopy=false
AllowAudioStreamCopy=true
```

Disabling Direct Stream alone is not sufficient to force video encoding.
Jellyfin can copy a compatible video stream inside an HLS transcoding job.
`AllowVideoStreamCopy=false` is therefore required on the PlaybackInfo request
to prevent `-codec:v:0 copy`.

Audio stream copying remains allowed because this option specifically requires
Jellyfin to rebuild the video stream. Jellyfin may still encode audio when the
source audio is incompatible with the Roku device profile.

## HEVC Video With Multichannel AAC

An HEVC SDR video may be compatible with Roku while its AAC 5.1 audio is not.
Automatic playback can therefore produce a partial transcode that copies the
HEVC video while converting the audio:

```text
-codec:v:0 copy
-codec:a:0 libfdk_aac -ac 2
```

Although the video codec is device-compatible, converting the audio prevents
whole-file Direct Play. Jellyfin rebuilds the output as HLS while retaining the
original video packets, timestamps, and keyframe layout. Timestamp or segment
handling on this copied-video path can cause seeking errors or repeated frames.

Automatic (Remux Disabled) still allows Direct Play when the complete file is
compatible. When fallback is necessary, `AllowVideoStreamCopy=false` makes
Jellyfin encode the video and generate a new video timeline and keyframe
structure. The incompatible AAC 5.1 audio is converted normally; compatible
audio would remain eligible for copying.

## Verifying Jellyfin Behavior

Inspect the Jellyfin transcoding URL and FFmpeg command after starting
playback.

### Allow Remux

A copied video stream confirms that remuxing was allowed:

```text
allowVideoStreamCopy=true
-codec:v:0 copy
Stream #0:0 -> #0:0 (copy)
```

Audio may be copied or encoded independently.

### Remux Disabled

For either Remux Disabled mode, a transcoding URL should contain:

```text
allowVideoStreamCopy=false
```

The FFmpeg command should use a video encoder such as:

```text
-codec:v:0 libx264
```

Hardware-accelerated Jellyfin installations may use an encoder such as
`h264_qsv`, `h264_nvenc`, or `h264_vaapi` instead. The important result is that
the command does not contain:

```text
-codec:v:0 copy
```

If the log still reports video stream copy, Remux Disabled was not applied
successfully.

## Playback-Issue Testing Order

For playback stalls, broken seeking, timing errors, repeated scenes, or
incorrect playback starts, test the options in this order:

1. **Automatic (Remux Disabled)** to retain Direct Play for wholly compatible
   files while encoding video whenever fallback is required.
2. **Force Transcode (Remux Disabled)** to require video encoding even when the
   original file could Direct Play.
3. **Force Transcode (Allow Remux)** to determine whether repackaging alone is
   sufficient.
4. **Automatic** as the normal baseline that permits every playback method.

If Remux Disabled works but Allow Remux does not, the source video stream or
its timestamp or keyframe structure is more likely to be involved than the
container alone.
