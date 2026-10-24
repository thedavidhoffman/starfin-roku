# Direct Play audio-track selection

## Status

Open investigation, documented October 20, 2026.

Source review identifies a gap between Starfin's negotiated audio selection and
the audio track actually played by Roku during Direct Play. An audible mismatch
has **not yet been reproduced on a device**. No production fix has been selected
or implemented for this issue.

This investigation is separate from the stream-change backward-position jump
addressed by enabling `seekMode="accurate"`. There is no evidence that audio-track
selection caused that jump.

## Potential user-visible behavior

For a directly played file containing multiple audio tracks, Starfin can display
the negotiated audio selection while Roku independently selects a different
track. A possible example is Starfin showing the file-default language while
Roku plays another language according to the device's audio preferences.

The most useful paths to investigate are initial Direct Play and switching back
to the file-default audio track after selecting another track.

## Starfin's current behavior

1. Media Options records the selected Jellyfin audio-stream index. Changing audio
   during playback requests a stream restart.
2. Playback negotiation sends `AudioStreamIndex` to Jellyfin.
3. `shouldForceStreamSelection()` compares an explicitly requested audio index
   against the file-default audio index. Selecting a non-default track disables
   Direct Play and requests server-side stream selection through remuxing or
   transcoding, according to the video mode.
4. Selecting the file-default track can still allow Direct Play. The static
   playback URL includes `AudioStreamIndex`, but the static response serves the
   original file rather than removing its other audio tracks. HTTP direct
   sources can use their original URL.
5. VideoPlayer does not assign Roku's native `audioTrack` or observe
   `availableAudioTracks` / `currentAudioTrack`. Its accepted audio index and
   descriptive metadata come from the playback-resolution response, not
   confirmation of the track Roku is playing.

The server-side selection safeguard means the absence of native `audioTrack`
assignment does not establish that every audio change is broken. The specific
unverified boundary is a directly played stream that retains multiple tracks.

Relevant Starfin source:

- [Stream selection](../../components/tasks/Video/VideoPlaybackInfoTask/Helpers/StreamSelection.bs):
  `buildStreamInfo`, `shouldForceStreamSelection`, `getDefaultAudioStreamIndex`,
  and `getResolvedAudioStreamIndex`.
- [Playback negotiation](../../components/tasks/Video/VideoPlaybackInfoTask/Helpers/PlaybackRequest.bs):
  `negotiatePlaybackInfo`.
- [Playback resolution](../../components/tasks/Video/VideoPlaybackInfoTask/Helpers/PlaybackResolution.bs):
  `getPlaybackFlags` and `buildPlaybackResolution`.
- [Media Options application](../../components/pages/Video/VideoPlayer/Helpers/StreamOptions.bs):
  `onMediaOptionsApplyTimerFire`.
- [Native player setup](../../components/pages/Video/VideoPlayer/Helpers/PlaybackSession.bs):
  `buildVideoContent` and `startVideoContent`.

## Comparison with Jellyfin Roku and Moonfin

The comparison is based on the local checkouts at `C:\dev\jellyfin-roku` and
`C:\dev\Moonfin\Roku`, not a claim about every released version.

| Responsibility | Starfin | Local Jellyfin Roku and Moonfin |
| --- | --- | --- |
| Request an audio stream from Jellyfin | Sends the selected audio-stream index during negotiation | Also send an audio-stream selection during negotiation |
| Select native Roku audio | Does not set `audioTrack` | Both assign `m.top.audioTrack = m.top.audioIndex.toStr()` when an index is present, with a `"2"` fallback |
| Observe available native tracks | Does not observe `availableAudioTracks` | Both register `onAvailableAudioTracksChanged` |
| Reconcile a preferred native track | No native track reconciliation | Match a stored preferred track name against Roku's available tracks, take its `Track` identifier, and reload playback |
| Verify what Roku actually plays | No `currentAudioTrack` confirmation | Jellyfin's available-track handler checks `currentAudioTrack` to avoid a redundant reload; Moonfin's inspected handler does not have that same guard |

Reference locations in the local checkouts:

- Jellyfin: `components/video/VideoPlayerView.bs`, initialization,
  `onAvailableAudioTracksChanged`, and `onVideoContentLoaded`.
- Moonfin: `Roku/components/video/VideoPlayerView.bs`, the corresponding
  initialization and handlers.
- Jellyfin: `components/ItemGrid/LoadVideoContentTask.bs`,
  `addAudioStreamsToVideo`, constructs preferred track names using
  `#uniq:<title>(<audio ordinal>)`.

These implementations inform the investigation; they are not proof that a
Jellyfin stream index always equals a Roku track identifier. Do not copy the
numeric assignment, fallback, or title-based mapping without checking the
actual tracks exposed by the relevant container and playback method.

## Platform and server evidence

[Roku's Video documentation](https://developer.roku.com/dev/docs/video) describes:

- `audioTrack`: the selected native audio-track identifier.
- `currentAudioTrack`: the track actually playing, which can differ from the
  selected track when the selected format cannot be played.
- `availableAudioTracks`: available tracks with `Track`, `Name`, and `Language`.
- Automatic selection based on device preferences and audio characteristics when
  an application has not explicitly selected a track.

The local Jellyfin server checkout provides additional evidence:
`C:\dev\jellyfin\Jellyfin.Api\Controllers\VideosController.cs`, in the static-stream
branch, returns the original file through
`FileStreamResponseHelpers.GetStaticFileResult`. Consequently, adding an
`AudioStreamIndex` query parameter to that static URL is not equivalent to
selecting the native track in Roku.

## Reproduction and verification needed

Choose a title that actually reports **Direct Play on the test Roku** and has at
least two distinguishable audio tracks, ideally different languages or main
audio versus commentary. Record the exact movie version or episode. A file with
multiple tracks that always transcodes is not sufficient to test this gap.

To identify a candidate in Starfin:

1. Check Media Options > Audio for multiple tracks.
2. Select Automatic video mode and turn subtitles Off to avoid subtitle burn-in
   forcing transcoding.
3. Start playback and confirm Media Options > Information reports Direct Play.

For that fixture, capture the following without recording authentication tokens
or unmasked stream URLs:

- File audio streams: index, title, language, codec, and default flag.
- Requested and resolved Jellyfin audio indices and actual playback method.
- Roku `availableAudioTracks`, `audioTrack`, and `currentAudioTrack` after startup
  and after each stream change.
- The audio selection shown by Starfin and the audibly identifiable track.
- Device audio preferences and Jellyfin account audio preferences.

Exercise initial Direct Play, selection of a non-default track, and selection of
the file-default track again. Confirm the playback method at every step rather
than assuming it remains Direct Play. Compare with remuxed/transcoded playback,
where the output track identifiers may differ from the original file's indices.

A confirmed defect requires evidence that the intended/displayed selection and
actual played track disagree. Numeric differences between Jellyfin and Roku
identifiers alone are not proof of a mismatch.

## Coverage and next decision

Existing unit coverage exercises requested and resolved audio indices and
negotiation behavior. Existing playback RTA results do not establish that the
audible/native audio track matches the selection on a multi-track Direct Play
fixture. This issue still needs a dedicated device investigation.

If a mismatch is reproduced, decide between native audio-track selection with a
verified mapping and extending server-side selection. Preserve distinct
Jellyfin and Roku identifiers, respect unavailable/unsupported tracks, and test
initial playback, stream changes, and changing back to Direct Play. Avoid adding
an unconditional `audioTrack` assignment before that evidence is available.
