# Theme Songs

Theme song playback support is implemented in the app, but libraries still need
theme song media sourced and attached on the Jellyfin side.

## Current App Support

- The Settings dialog exposes a Theme Music toggle.
- Movie and TV show pages emit a source request after loading eligible metadata
  when theme music is enabled. ThemeAudioController owns the Jellyfin lookup.
- `ThemeSongsTask` calls Jellyfin's item theme song endpoint:
  `/Items/{itemId}/ThemeSongs`.
- `ThemeAudioController` resolves playback info for the returned theme song item and plays
  it through the app shell.
- Theme audio is stopped when navigating away from media pages or starting
  playback.

## Jellyfin Source

Use the Jellyfin Theme Songs plugin to import or manage theme song media:

https://github.com/danieladov/jellyfin-plugin-themesongs

The app expects Jellyfin to expose imported theme songs through the normal
`ThemeSongs` item endpoint. The Roku app does not currently fetch MP3 theme
files directly from third-party URLs.

## Candidate Theme Source

TV theme MP3s can be sourced by TVDB id from:

```
https://tvthemes.plexapp.com/{tvdbId}.mp3
```

Example:

```
https://tvthemes.plexapp.com/74380.mp3
```

`74380` is the TVDB id for Magnum P.I.

```
televisiontunes.com
```

## Open Work

- Decide whether sourcing is a manual library-management step or something
  documented for server setup.
- Confirm how the Theme Songs plugin maps TVDB ids to downloaded theme files.
- Verify that imported theme songs appear in Jellyfin's `/Items/{itemId}/ThemeSongs`
  response for both series and movies.
- Keep the Roku app using Jellyfin-hosted theme song items rather than direct
  third-party MP3 URLs, so playback continues to use the existing authenticated
  media pipeline.

Playback requests follow the shared [media authentication](media-authentication.md) rules.

ThemeAudioController accepts source requests containing server, token, userId,
sourceItemId (movie or series), and title. It looks up the song before resolving
that song's playback stream. The resolved song ID remains internal to the
controller; pages retain source requests for trailer restoration. Only active
Movie and TVShow pages may emit new source requests, including when settings
enable theme music. Settings distributed to retained inactive pages cannot restart
their themes. This eligibility check does not cancel a request already accepted
by the controller when navigating into a season.

Lookup and stream resolution each use a correlated latest-request lifecycle and
two alternating task nodes. ThemeSongsTask echoes requestId on success and every
failure. A new selection immediately invalidates old stream resolution; older
lookup results cannot advance playback. Stop and session replacement invalidate
both stages without resetting generation counters. Empty or malformed themes
and lookup errors leave navigation usable and audio stopped.

The single-season shortcut submits the series source after opening TVSeason.
Removing TVShow does not cancel controller-owned work. Normal series-to-season
navigation preserves existing theme playback; direct season entry does not start
a theme. Back from the shortcut returns to its origin and stops the theme.
Ordinary playback return does not automatically restart it.

Opening a trailer stops both theme stages and audio. On normal trailer closure,
the matching visible source page resubmits its source request through the existing
settings and overlay checks, performing a fresh lookup. Disabling theme music,
starting playback, navigating away, or changing session cancels pending work.

Component coverage includes both asynchronous stages, stale and duplicate results,
same-source generations, errors, cancellation, session capture, shortcut routing,
direct-entry exclusion, and trailer suppression/restoration. Device and audible
playback verification remain subject to the development-cycle gate.

## Device automation

`tests/automation/specs/theme-music.spec.mjs` uses the configured Jellyfin test
account and two user-provided fixtures: **Buck Rogers** (one season including
Specials) and **Magnum, P.I.** (1980; multiple seasons). Title prefixes must resolve to
one series each, and both must expose a theme song through Jellyfin. Missing or
ambiguous fixtures fail explicitly instead of silently skipping coverage.

The suite checks the real Roku Audio node reaching playing with the expected
Jellyfin song identity, shortcut Back navigation stopping audio, normal season
navigation preserving the same stream without another lookup, disabling music,
episode playback cancellation, and direct-season/disabled-entry exclusion.
Selection events use the existing page interfaces; this suite tests app routing
and playback rather than library-search remote navigation.

Theme preferences are changed only from Home through the visible System menu.
The disable scenario returns Home, turns music off, then reopens Magnum and
asserts that no new lookup starts. It does not claim to cover disabling a setting
while remaining on a series page; immediate cancellation is component coverage.

The delayed-lookup scenario enables music from Home, then installs a test-only
reverse proxy before opening Magnum. Fixture setup republishes the current
runtime session with only its server endpoint changed, preserving the saved
account and settings; this is network setup, not authentication UI coverage.
It waits for proxy-backed Home, opens the series, holds the real ThemeSongs
response, opens a season, then releases it. Metadata and audio bytes still come
from Jellyfin. The proxy must be reachable from Roku. Cleanup relaunches the
saved real-server session before closing the proxy. No detail-page request reload,
hidden Settings dialog, or production test hook is used.

Tests restore the original theme/shortcut settings and the episode/series user
data affected by the playback case. Evidence records song IDs and screenshots,
not authenticated stream URLs. The original seven-case suite passed on 2026-11-14,
but its delayed-lookup and disable cases opened Settings from an inaccessible
series-page context. That run is not evidence for the corrected workflows.
The revised suite passed all seven cases, including cleanup, on 2026-11-14
(report: out/automation-results/2026-11-14T16-32-36-050Z/report.html).
Function-header and tracked/untracked whitespace checks also passed. Test setup
uses the MediaBrowser Authorization header accepted by this server and the catalog
title "Magnum, P.I." (1980). Rooibos was explicitly excluded from this verification.
A playing Audio node verifies the device pipeline, not audible TV/speaker output;
listening or external audio capture is still a separate check.
