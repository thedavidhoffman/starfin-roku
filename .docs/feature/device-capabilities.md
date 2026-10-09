# Playback Device Capabilities

`source/DeviceCapabilities.bs` builds the PascalCase JSON device profile posted
to Jellyfin during video playback negotiation. It probes the current Roku device
and output configuration for each request; capabilities are not persisted.

## Audio

- Direct-play video profiles probe audio support for each container, including
  Opus. Opus is not advertised as a standalone audio format by this video profile.
- A container needs at least one supported video codec and one supported audio
  codec before its direct-play profile is emitted. Jellyfin treats an empty
  `AudioCodec` list as unrestricted support, so failed audio probes must not
  produce an empty allow-list. The AC3 workaround below can still supply a codec.
  A container with no advertised audio support negotiates another playback path,
  including for silent video.
- TS and MP4 HLS transcoding profiles have separate audio codec lists. Support
  reported for one container does not grant support in the other. If all probes
  for a container fail, the existing AAC fallback remains.
- `VideoAudio` codec profiles probe channel counts in descending order: 8, 6, 2.
  The highest successful count becomes a required `AudioChannels` upper bound
  for that codec. AAC also excludes the Main audio profile, following Jellyfin Roku.
- If no channel probe succeeds, no channel limit is invented. The exception is
  AC3 surround false-negative workaround: direct-play AC3 is assumed only outside
  MP4, as in the official client, with a six-channel fallback limit in Starfin.
  EAC3 and DTS require positive codec/container probes; surround output alone
  no longer implies support for them.
- The existing global transcoding output cap remains two channels for stereo
  output and six for surround. Per-codec constraints can lower that cap. An
  eight-channel direct-play source remains eligible when its codec probe allows it.

## Video

Required video width and height bounds come from `roDeviceInfo.GetVideoMode()`.
A TV with a 1080p UI and 2160p video output therefore advertises 3840x2160 playback.
Unrecognized video modes retain a 1920x1080 fallback. `GetDisplaySize()` and
`GetMaxScreenImageSize()` continue using the UI display mode for image sizing.
Playback negotiation logs report the video bounds and their source.

AV1 direct-play support uses a codec-only probe because Roku can incorrectly
reject AV1 when the container is supplied. HLS output capability probes remain
container-specific. See [Video Playback Options](video-playback-options.md).

H.264, HEVC, VP9, and AV1 additionally probe profiles and levels without a
container. H.264 accepts both Roku codec spellings; HEVC constraints apply to
both Jellyfin codec aliases. Supported baseline H.264 includes constrained
baseline aliases. Roku's AV1 Main 10 maps to Jellyfin/FFprobe's Main profile.

If H.264 Baseline probes fail but Main or High succeeds, a compatibility fallback
adds `baseline`, `constrained baseline`, and `constrainedbaseline`, following
Jellyfin Roku's policy. This fallback is eight-bit and uses the lowest maximum
level among the detected Main/High profiles. A successful Baseline probe retains
its own level instead. Main and High keep their separate limits, and no Baseline
fallback is added when every H.264 profile probe fails.

Video bit depth is limited to eight for H.264. Successful Main 10 or VP9 Profile 2
probes permit ten bits for those profiles; other successful probed profiles
permit eight. Each profile keeps its own maximum level and bit depth. Levels
are translated to the values retained by Jellyfin:

| Codec | Roku level example | Jellyfin level |
| --- | --- | --- |
| H.264 | 4.1 | 41 |
| HEVC | 5.1 | 153 (`level_idc`) |
| VP9 | 5.1 | 51 |
| AV1 | 5.1 | 13 (`seq_level_idx`) |

The AV1 mapping follows [FFmpeg's sequence-level reporting](https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/av1_parser.c)
and differs from the inspected Jellyfin Roku checkout's conversion.

When several profiles succeed, `ApplyConditions` scope each level/depth limit
to its profile. Jellyfin combines all matching codec profiles, so these are
conditional constraints rather than alternative allow-lists. For AV1, eight-bit
and ten-bit Main are further distinguished by source bit depth. Missing AV1
depth applies both limits conservatively. Missing or unsupported profile names
use the lowest supported level and depth, providing conservative transcoding
limits; known unsupported names still fail the common direct-play allow-list.
Scoped constraints also specify the corresponding output profile, keeping
Jellyfin's transcoding profile choice paired with that profile's limits.

Display HDR10, HDR10+, HLG, and Dolby Vision flags determine allowed video range
types, following the official client's base-layer compatibility policy. SDR
and Dolby Vision with an SDR base layer remain available. VP9 does not advertise
Dolby Vision decoding. H.264 does not acquire HDR10/HLG support from display flags.

Profile, level, bit-depth, and range conditions are optional when source metadata
is absent. If detailed probes all fail, profile and level conditions are omitted
instead of emitting an empty profile list or a zero level. Bit-depth constraints
are also omitted without positive evidence except for H.264's eight-bit ceiling.
Unavailable display properties omit range conditions. The 40 Mbps bitrate limits
remain unchanged.

## Diagnostics

Each video PlaybackInfo request logs eight compact capability lines before the
request body: device model/name, Roku OS version/build, raw video and UI display
modes, audio output mode, the codec-only AV1 result, audio probe booleans for each
of MP4/HLS/MKV/TS, and container-qualified AV1 results for TS/MP4 transcoding.
Audio lines distinguish the AC3 surround assumption from the probe result and
report whether a direct-play profile was emitted. Probe booleans reflect the
capability helpers' decisions: false also includes an unavailable Roku response.

The optional diagnostics array is filled during profile construction, reusing
the existing codec probes rather than running them again. The playback task
writes those lines through its normal Logger, making them available in the
console and collected application logs. Diagnostics are not sent to Jellyfin as
device-profile fields, and do not alter playback policy. Subtitle renegotiation
and recovery requests each produce their own summary. Device names are the
model display name, not the user-assigned friendly name or a unique identifier.

## Verification

The DeviceCapabilities Rooibos suite covers container isolation, Opus advertising,
per-codec channel limits, the AC3 exception, empty audio-list omission, separate
UI/video dimensions, profile/level conversions, mixed-profile level and bit-depth
limits, HDR flags, and unavailable probe results. Runtime verification remains subject to
the development-cycle gate. Device checks should cover stereo and surround
outputs, AV1/EAC3 and Opus titles, SDR/HDR displays, and unsupported video variants
that should negotiate transcoding instead of failing in the Roku player.
