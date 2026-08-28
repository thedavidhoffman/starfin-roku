# Music Video Playback

Music videos use the normal video player and playback queue, with a small set
of deliberate presentation and progress-policy differences. Jellyfin items are
recognized as music videos when their `Type` is `MusicVideo`.

## Introductory Artist and Title

For the first five seconds of a music video, the player displays introductory
metadata at the bottom-left of the screen:

- When `Artists` contains values, their names appear on the first line.
- The video title appears beneath the artists using the larger bold title style.
- When `Artists` is absent or empty, the artist line is blank and the title
  remains in its normal bottom-aligned position.

The title's bottom edge aligns with the bottom edge of the contextual Skip
button. The presentation is position-based and is available while the playback
position is greater than or equal to zero and less than five seconds.

Opening playback controls or another player overlay temporarily hides the
introductory metadata. It may return when the overlay closes if playback is
still within the five-second window and the presentation has not been
dismissed. Back dismisses the introductory presentation for the current item.
The dismissal state resets when the queue advances to a different item.

## Random Playback Skip Button

The contextual button displays `Skip` during the first five seconds only when
all of the following are true:

- The current item is a music video.
- Playback was started from the music-video random-play queue.
- The queue has a next item.
- The Skip presentation has not been dismissed for the current item.
- The video is actively playing and no controls, cast, or seek overlay is open.

Selecting Skip advances through the existing playback queue to the next random
item. It also dismisses the artist/title presentation before changing items.
Back dismisses both the button and artist/title presentation without advancing.

The button shares its screen location with `Skip Intro`. Random Skip takes
precedence during its five-second window. Outside random music-video playback,
the established media-segment logic may display `Skip Intro` instead. Selecting
either action dismisses the introductory music-video metadata immediately.

## Playback Progress and Watched State

Music videos intentionally do not participate in resume or watched-progress
tracking:

- The player does not emit local `playbackProgressChanged` events.
- The current item, playback request, and queue item are not updated with a
  playback position or completed state.
- The periodic 30-second Jellyfin progress timer is not started.
- Pause, seek, and periodic playback updates are not sent to Jellyfin.
- Standard and detailed media cards do not render a progress bar or watched
  indicator for music videos, even if existing Jellyfin `UserData` contains
  `Played`, `PlayedPercentage`, or `PlaybackPositionTicks` values.

This is controlled by the shared `MediaPlaybackPolicy.TracksProgress()` policy.
Other video types retain their existing resume, progress, and watched behavior.

The Home page's Continue Watching request excludes `MusicVideo` items at the
Jellyfin API boundary. This also keeps music videos with stale or pre-existing
resume data out of the row without deleting that server-side data. Continue
Listening, Next Up, and library browsing are not affected by this exclusion.

## Jellyfin Playback Lifecycle

Music videos still report the minimum Jellyfin playback lifecycle needed for
session visibility and prompt transcode cleanup:

- One playback-start report is sent with `PositionTicks = 0`.
- One playback-stop report is sent with `PositionTicks = 0`.
- Both reports retain the normal item, play-session, media-source, live-stream,
  play-method, and seek-capability identity.

Actual playback position is never included in these reports. Natural
completion, Back, random Skip, playback error, and replacement by another queue
item all use the normal player shutdown path so an established Jellyfin session
receives its stop report.

This start/stop-only design is intentional: suppressing all lifecycle reports
would prevent progress persistence, but it could also leave Jellyfin unaware
that playback ended and delay cleanup of transcoding resources.
