# Remote Keys

`source/Remote.bs` defines the string-valued `Remote.Key` enum used by remote
input handlers and helpers that accept remote key input. It preserves the
existing values: `up`, `down`, `left`, `right`, `back`, `OK`, `select`, `play`,
`playpause`, `rewind`, `fastforward`, and `options`.

Handlers retain their existing press/release behavior, aliases, focus movement,
and event consumption for canonical input. Handlers compare input directly
against the enum without lowercasing. Confirmation uses `OK`; directional keys
and the supported `select` alias use lowercase. Noncanonical casing such as
`ok`, `Select`, or `BACK` is not normalized into a supported key.
The enum does not make all handlers accept every alias.

Text alignment, chevron directions, and playback seek-direction state remain
separate contracts even where they use the same strings. Tests keep literal
remote inputs to independently verify handler behavior, and `Remote.spec.bs`
checks each enum member against its literal value.

## Quick playback

Remote Play launches the focused Movie, Episode, Video, MusicVideo, or MusicAlbum
from existing Home, Search, library/collection/playlist contents, season episode
lists, Person related-item lists, music library albums, and artist album lists.
Libraries, collections, folders, series, seasons, artists, playlists themselves,
and photos remain navigation items. TMDB filmography credits are not Jellyfin
media and cannot be played. Missing and virtual items are excluded.

Movie and episode details use their existing Play/Resume action from any content
focus area. Season summaries do not support the shortcut. Key releases, browsing
controls, loading states, and overlays do not launch playback. OK retains its
existing navigation behavior. VideoPlayer and AudioPlayer retain their existing
Play pause/resume controls; selecting another music track still uses OK.

Remote Play uses the same MainScene-owned return context as ordinary video and
album playback. It preserves the browsing destination through next-episode
prompts. A new title launched from Person replaces the destination rather than
being blocked by the earlier shortcut; closing Person after replacement playback
returns through its saved original navigation context.

## Instant Replay

The remote's Replay button seeks video backward by ten seconds, clamped to the
beginning. It preserves playing or paused state and shows the existing playback
controls. There is no interval setting, and subtitle selection is unchanged.

Replay works with controls visible or hidden during active, seekable playback.
Seek preview, cast browsing, startup/recovery, buffering, stopped playback, and
nonseekable video consume the press without seeking. Key releases do not seek.
Audio playback and voice commands are outside this behavior.

Functional tests cover the key contract, seek target, state preservation, controls,
and rejection paths. The TV playback automation includes one Replay case using
the configured episode, with tolerance for sync-frame seeking and sampling delay.

## Automated workflow coverage

`tests/automation/specs/remote-keys.spec.mjs` sends ECP OK and PLAY keypresses to
focused production controls. Setup reuses existing navigation events and real
server-loaded items; it does not inject playback-selection events for the key
being tested. The cases cover:

- Movie library and Search: OK opens details; PLAY launches directly and restores
  the selected grid/result item.
- Home: required paired OK/PLAY cases dynamically select Movies and Episodes from
  Recently Added and Continue Watching, and an Episode from Next Up. Series cards
  are not episode playback fixtures. Each case records the selected item and row
  IDs and checks return focus against both. Continue Watching requires saved
  progress and verifies the negotiated resume position. Missing eligible items
  fail with a message identifying the required row and media type; these cases
  do not skip or create account history. Setup enters through Home's `focusHome`
  interface and sends Up/Down keys to the target shelf, waiting for each focus
  transition. It selects the item within that shelf and verifies both row key and
  focused item ID before OK/PLAY, keeping Home's tracked shelf aligned with focus.
- Season episodes: OK opens details; PLAY carries the episode queue. Real playback
  completion after a seek exercises next-episode prompt cancellation/continuation
  and retention of the season destination. After continuation, return focus follows
  the latest played episode; cancellation retains the original episode focus.
- PLAY from movie/episode description focus, library-container rejection, and
  rejection while a library sort dialog owns focus.

The existing episode playback suite retains PLAY pause/resume coverage. These
tests use the existing HD/FHD automation runner without resolution-specific
coordinates. Movie and episode fixtures reuse `DEEP_LINK_CASES` and
`TVSERIES_SMOKE_TEST`. Home media is discovered from the rendered rows, with
selected item and row IDs recorded in the report. Required Home rows fail when
eligible items are missing. The example configuration documents the prerequisites.

Person, playlist, album, home-video, and music-video workflows are outside this
automation suite; their production support and unit coverage remain unchanged.

Tests relaunch after each case to clean players, pages, and overlays.
Failures capture the current surface before relaunch so cleanup does not erase
the failure evidence. Playback can update server progress and watched state,
including the completion cases, so use suitable test media.

