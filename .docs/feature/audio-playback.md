# Audio Playback

Album playback is owned by `AudioPlayer`, which loads the album track list,
resolves each selected audio stream, advances on track completion, and owns the
music screensaver lifecycle.

Album loading and stream resolution each keep one active request and one
replaceable pending request, alternating between two task nodes. Each request
captures its session and selection; only the latest matching generation can
update playback. Closing the player or replacing its session cancels outstanding
work without reusing generation IDs. Pause and resume preserve pending resolution.

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
music-library entries themselves do not play. No standalone track browsing or
playback mode is added: tracks remain in AudioPlayer, where OK selects a track
and continues the album, and remote Play retains pause/resume behavior.

## Shared return navigation

Ordinary album selection and remote Play both pass their originating page to
MainScene's shared playback return context. AudioPlayer requests no longer carry
navigation source labels. Closing restores that exact page and its captured
header visibility through the page's existing activation/focus path; a retained
music library cannot override a Home launch. Stale close events from a replaced
AudioPlayer are ignored. Completing the final album track keeps AudioPlayer open.
