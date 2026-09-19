# Home Media Playback

Home Media libraries contain hierarchical folders, photos, and videos. Jellyfin
identifies their playable videos with the generic `Video` item type, so Starfin
uses the shared video player progress reporting and media-card progress rendering.

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

Home videos use the normal VideoPlayer reporting lifecycle: actual-position start
and stop reports, periodic 30-second updates, and pause/seek updates. Local
progress events update the originating library and Home shelves. Completion is
reported to Jellyfin and clears local resume progress. Jellyfin controls whether
an item meets its server-side Continue Watching thresholds.

Poster, thumbnail, detailed, and Home shelf cards show saved progress. Home-video
cards set `showWatchedIndicator: false` independently of progress eligibility;
completion badges and watched actions are hidden. Photos and folders still do
not show progress, and music-video policy is unchanged.

## Resume Dialog

Selecting a video with positive saved playback ticks opens HomeVideoPlaybackDialog
through the top-level OverlayHost. It shows a nonfocusable thumbnail card with
its existing title/progress presentation and VideoToolbar with only Resume and
Restart. Both button labels stay visible in this dialog, with Resume initially
focused. The row fills the 441-pixel card width: Resume is 214 pixels wide and
Restart is 215 pixels wide, separated by a 12-pixel gap. Widths stay fixed as
focus moves, and each icon/text pair is centered within its button. Other
toolbars retain their existing sizing and focus-driven labels. There is no
additional resume-time label.
Resume passes the exact saved ticks; Restart explicitly passes zero. Audio,
subtitle, and playback-mode options remain available inside the player.

Videos without progress play immediately. Home's generic `Video` selections,
including Continue Watching, follow this flow even when library origin is
unavailable. Movie and Episode routing is unchanged, as are deep links and
automatic playback.

Back dismisses the dialog without changing progress and returns focus to the
selected card. Library pagination may finish behind the dialog but cannot reclaim
focus until it closes. Home retains the originating shelf key and video ID so
background shelf rebuilds or reordering do not change the return target. If the
original shelf or item disappears, focus falls back to an available shelf/card.
Starting playback closes the dialog first; stopping returns to
the originating shelf or library. Pages own selection and focus handling;
MainScene only routes the overlay result and existing playback events.
