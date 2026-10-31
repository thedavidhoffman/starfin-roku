# Audio Playback

Album playback is owned by `AudioPlayer`, which loads the album track list,
resolves each selected audio stream, advances on track completion, and owns the
music screensaver lifecycle.

Album loading and stream resolution each keep one active request and one
replaceable pending request, alternating between two task nodes. Each request
captures its session and selection; only the latest matching generation can
update playback. Closing the player or replacing its session cancels outstanding
work without reusing generation IDs. Pause and resume preserve pending resolution.

## Screensavers

Starfin supports None, Bouncing artwork, and Starfield during music playback.
None is the default and leaves the player visible. Persisted `roku` and unknown
screensaver values normalize to None.

While audio is playing, Starfin disables Roku's native screensaver. When Bouncing
artwork or Starfield is selected, it starts that overlay after the selected
delay; None starts no overlay. Keeping Starfin active is
required so the player can observe track completion and advance the album. The
native Roku screensaver is restored when playback pauses, stops, fails, completes
the album, or the audio player closes.

## Playback controls and diagnostics

The Play control pauses active playback, resumes paused playback, and resolves a
fresh stream for the current track after stopped, errored, or completed playback.
Interrupted playback seeks to its previous position after the replacement stream
begins; a completed track restarts from the beginning.

Audio state logs include the current track ID, position, track-change status, and
Roku error details. Stream URLs and credentials are not logged by the player.

Playback requests follow the shared [media authentication](media-authentication.md) rules.

## Remote album launch

Remote Play on an album in Home, MusicLibrary, or an artist's album list launches
the existing ordered album queue at its first track. MainScene retains and restores
the originating page and its browsing focus when AudioPlayer closes. Artist and
music-library entries themselves do not play. No standalone track browser is added: album tracks remain in AudioPlayer, where OK selects a track
and continues the album, and remote Play retains pause/resume behavior.

Home's Continue Listening selection opens its audio item as a one-track queue
and resumes at its saved playback position. This bypasses album-track loading
and invalidates any older album request. Items without saved progress start at
zero; ordinary album requests still load and play their ordered track list.

## Shared return navigation

Ordinary album selection and remote Play both pass their originating page to
MainScene's shared playback return context. AudioPlayer requests no longer carry
navigation source labels. Closing restores that exact page and its captured
header visibility through the page's existing activation/focus path; a retained
music library cannot override a Home launch. Stale close events from a replaced
AudioPlayer are ignored. Completing the final album track keeps AudioPlayer open.

## Listening history and terminal saves

AudioPlayer reports every played track, including album tracks and standalone Home
Continue Listening items. Theme music is excluded. AudioPlaybackReporter owns the
ordered writes independently of the player page, using PlaystateTask and explicit
account, item, media-source, and playback-session snapshots. Audio resolution returns
this metadata alongside the existing stream information.

Reports include one start, progress every 30 seconds while playing and on pause/resume
or seek completion, and one stop for completion, skipping, interruption, or closure.
Completion uses duration; interruption preserves the last valid position. Queued
progress for the same session coalesces, while start/stop boundaries retain order.
The reporter alternates task nodes and rejects superseded response identities.

Closing returns immediately without cancelling terminal reporting. Home receives
local progress immediately and waits for terminal settlement before refreshing
Continue Listening. A settlement event cannot replay an older track snapshot over a
newer change. Each audio report has a 10-second timeout; terminal failures retry once,
periodic failures do not retry. Final failure presents the existing application message
for the current account, retains the local view, and defers another server snapshot
until activation. It never claims that the bookmark was saved. Old-account reports
retain their captured session and cannot update the new account's Home.

The RTA audio lifecycle cases require a seekable AudioBook item at least thirty minutes long.
Set `STARFIN_AUTOMATION_AUDIO_ITEM_ID` to select one explicitly; otherwise the tests
look for a suitable item. Status-changing tests snapshot and restore test-account user
data after terminal reporting and channel shutdown.

Standalone audiobook playback preserves the Jellyfin `AudioBook` type through Home
selection, playback reporting, and Continue Listening reconciliation. Jellyfin decides
resume eligibility: ordinary music `Audio` tracks do not retain bookmarks on 10.11.11.
Audiobook bookmarks must fall within the server-configured resume thresholds.
