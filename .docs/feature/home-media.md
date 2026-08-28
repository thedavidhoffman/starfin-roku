# Home Media Playback

Home Media libraries contain hierarchical folders, photos, and videos. Jellyfin
identifies their playable videos with the generic `Video` item type, so Starfin
carries an explicit Home Media playback policy from the originating library or
Home latest row into the shared video player and media cards.

## Photo Viewer Resolution

The photo viewer always uses the application's 1920x1080 SceneGraph coordinate
space for its full-screen poster geometry. Roku scales that scene to the output
display, including 1280x720 devices. Image requests remain resolution-aware:
720p devices request images up to 1280x720, while FHD devices request images up
to 1920x1080. Keeping scene geometry separate from download sizing prevents a
720p device from scaling the viewer twice and leaving the photo undersized.

Photo navigation chevrons retain a 24-pixel physical margin from the display
edges. The FHD scene inset is 24 logical pixels at 1080p and 36 logical pixels
at 720p, where Roku's final scene scaling converts it to the same 24-pixel
visible margin.

## Playback Progress and Watched State

Home Media videos intentionally do not participate in resume or watched-progress
tracking:

- The player does not emit local `playbackProgressChanged` events.
- Items and Jellyfin `UserData` are not updated locally with playback position or
  completion state.
- The periodic 30-second Jellyfin progress timer is not started.
- Pause, seek, and periodic playback updates are not sent to Jellyfin.
- Standard and detailed media cards do not show progress bars or watched
  indicators, even when existing Jellyfin data contains progress or played state.

The policy is explicit and source-scoped. Ordinary Jellyfin items whose type is
also `Video` retain normal progress behavior when they do not originate from a
Home Media surface.

## Jellyfin Playback Lifecycle

Home Media videos still send the minimum playback lifecycle required for
now-playing visibility and prompt transcode cleanup:

- Playback start is sent once with `PositionTicks = 0`.
- Playback stop is sent once with `PositionTicks = 0`.
- No intermediate playback-position updates are sent.

The normal shutdown path sends the stop report for Back, natural completion,
playback errors, replacement, and internal playback restarts.

Existing Jellyfin resume data is not deleted. The Home Continue Watching query
is also unchanged because Home Media videos share the generic `Video` type with
videos outside Home Media and cannot be safely excluded by type alone.
