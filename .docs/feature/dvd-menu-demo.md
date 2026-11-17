# DVD menu demo and ISO playback POC

The temporary **DVD Demo** HeaderButton occupies the top-left account-badge area
when Display Account Badge is off. From Header Home, press Left to reach it.
Home remains the normal header focus entry. Enabling the badge hides the demo
button without changing the saved setting.

DVD Demo opens the transparent `DvdLibraryPage` inside the normal app shell.
The configured ThemeBackground, top navigation and clock remain visible. The
browser owns catalog discovery: one enabled library opens directly; multiple
libraries appear as poster cards using the existing placeholder artwork. No
library-selection dialog is opened. Back from a multi-library drilldown restores
the focused library card; Back from a single library or the root returns Home.
Up from the first poster row focuses the header; Down returns to the browser.

## Metadata browser (plugin 0.1.20)

The browser displays six posters across in one visible, vertically scrolling row,
below the app header. It shows the library heading and card labels, without a
focused-title overview/details block. Overviews remain in the data for future UI.
ScrollingLabel uses maxWidth=252; only the focused card scrolls overflowing text.
Single-disc captions show the year when present; grouped cards show disc count.
The browser has no footer control hints or Options refresh action. OK opens the focused card and Back retains the navigation described above. Empty and failed libraries show page-owned retry instructions; OK retries an empty or failed result.

Discs are grouped only within the selected library by nonempty `metadataId`,
normalizing UUID case/hyphens. Missing metadata IDs produce individual disc cards;
names and provider IDs never merge groups. Groups retain catalog order and use
the first member's metadata. Original disc labels are retained in the multidisc picker. OK on one disc opens its menu directly. OK
on a multi-disc group opens a top-level disc picker with original labels, sorting
positive disc numbers first, then labels; unnumbered discs follow. Back dismisses
that picker to the same focused card. The disc picker uses an 800 x 590 dialog with a 680-pixel-wide list, five visible 72-pixel rows, and floating focus. Additional discs scroll naturally without wrapping; there is no right-hand detail label. Unavailable ISO content remains browsable.

Posters use explicit session authentication and preserve the full `?v=` cache key. The client appends `width=252` at 1080p or `width=168` at 720p to request the displayed pixel width instead of the full-size image, after validating the supplied metadata path.
A separate metadata-poster path validator permits only the plugin's UUID-scoped
Metadata/Poster route and version query. Shared six-column mask/focus assets keep
artwork and native grid highlights aligned. Each recycled card creates a fresh
Poster and checks node identity before applying load events; missing, loading,
and failed artwork retain a local placeholder.

MainScene retains the hidden browser while DvdPlayer is open. Back from the DVD
root restores the app header and focuses the retained browser grid without fetching
library data or rebuilding poster nodes. Selection and scroll position remain intact.
Reopening DVD Demo from Home creates a new browser and fetches fresh data.
Loading blocks selection until its correlated request completes. Closing a page
cancels its request and ignores stale responses. Authentication expiry follows
the existing task observation route. Account/session reset removes both pages.
Identify, scanning, and metadata configuration remain in Jellyfin administration.

## Ownership and isolation

`components/pages/DvdPlayer/` owns the fullscreen feature and its `Helpers/`
files. Geometry, navigation state, rendering, and selection construction remain
component-local; no DVD helper is added to `/source`. LibraryModel remains feature-local; DvdLibraryPage owns loading, grouping, and grid focus. The API task lives under
`components/tasks/DvdPlayer/`. MainScene only passes explicit session context,
hosts the browser/player, stops theme audio, and routes their return focus.
The existing player, playback negotiation, progress, and watched-state flows
are not used. Release version metadata and the plugin project are unchanged.

## Plugin contract and authentication

The task starts at `Starfin/Dvd/Libraries` (`starfin-dvd-library-catalog/1`),
follows the selected `libraryPath` (`starfin-dvd-library/1`), and fetches the
selected `manifestPath` (`starfin-dvd-disc/1`) on title selection. Embedded demos
are not injected or used as a fallback. The returned disc/library UUIDs are
matched across compact/hyphenated forms. Feature-local `Helpers/Paths.bs` checks
returned relative paths against the selected library/disc, rejecting external
URLs and traversal. Asset generations and playback start paths come from the
manifest; the client does not construct demo URLs. Plugin-configured libraries
are available to authenticated users, without Jellyfin library-specific access
restrictions; no admin configuration or filesystem paths are requested.
The inspector-derived plugin contract intentionally uses camelCase, unlike
ordinary Jellyfin DTOs. No mixed-case fallback fields are used.

All URLs retain the configured Jellyfin base path. JSON requests use
`JellyfinAuth.BuildTokenHeaders`; original images use a scoped HTTP agent with
the same Authorization header; previews use `JellyfinAuth.CreateContent` and a
dedicated Video HTTP agent carrying `Authorization: MediaBrowser …`. Tokens
never enter query strings. Catalog and manifest failures produce a page-owned
error with OK to retry and Back to exit. Requests carry generation IDs and are
invalidated on reload/deactivation. Tasks participate in the existing shell
authentication-expiry observation.

A rescan can invalidate generation-specific assets. A failed menu image triggers
one fresh manifest load per page before showing an error; it cannot interrupt
active content playback. Options on a menu explicitly reloads the manifest and
returns to its current root with fresh selection state. Preview failures retain
the still and offer this refresh action instead of automatically retrying HLS.
Removed libraries/discs disappear on refresh, and HTTP errors remain retryable.
Absent initial menus show navigation unavailable. A partial scan without a default
selection may still browse supported menus; Resume cannot invent a title, and
unsupported actions continue to show an explanation without issuing playback.

## Rendering and navigation

The menu is centered on black inside the app's 1920x1080 design coordinate
space. Its declared display aspect ratio determines the fitted rectangle;
source width/height separately determine hotspot scale. For the fixture's
720x480, 4:3 menus, the rectangle is 1440x1080 at x=240. The still, preview,
and highlight layers share this rectangle. Title-set zero uses the video
manager's menu video attributes.

The screen's `buttonGroup` (default 1) selects buttons from the first navigation
record. Hidden buttons retain directional geometry without a visible highlight.
Raw `autoAction` focus executes only a reviewed navigate action, honors destination
focus, and uses a visited screen/button set with a 16-transition limit to reject
cycles. Other DVD commands remain unexecuted. Focus
uses a requested button, then forcedSelect, then the first button. Arrow keys
follow the supplied neighbor IDs, with unavailable targets retaining focus.
OK uses reviewed menu-map actions only; commandHex and forced activation are
never executed. Hotspots are focusable with translucent gold fill and borders.

Menu previews prefer the optional `disc.menuAssets[].previewLoop` from plugin
0.1.2. This relative path resolves against the configured server base URL,
including any base path. It plays as live HLS with audio enabled, native looping
disabled, and no seeking. The plugin repeats the clip; the client never treats
live duration as an approaching EOF or covers video at source-clip boundaries.
Older manifests without `previewLoop` retain MP4 playback through `previewVideo`,
also with audio enabled. Still-only assets remain artwork only.

The same scoped authentication config applies to the player and content. Roku's
[content metadata documentation](https://developer.roku.com/dev/docs/content-metadata)
describes HTTP headers and dedicated agents, but header delivery on initial
playlists, refreshes, and child segments remains unverified on the device.

HLS keeps the still visible until playback advances, covers genuine buffering,
and retains the still on errors, unexpected EOF, or timeout. Its covered timeout
is 35 seconds to allow the plugin's 15-second startup deadline plus Roku
buffering. There is no automatic retry. A failed HLS URL has a 30-second cooldown
within the page instance, including menu revisits and message dismissal. A later
attempt opens the original manifest playlist URL, never a cached segment URL.
Roku's own HTTP retry behavior and handling of the server's 503 response still
need device verification. HLS failures stay on artwork; MP4 is the compatibility
path for manifests without HLS. Stopping or switching menus releases the player;
no server stop API is called. Shared server streams expire after 60 seconds idle
and may start playback partway through the source clip.

Finite MP4 samples use the Video node's native `loop` field.
Loop boundaries retain the same Video node and content instead of stopping and
recreating the player. The original still remains loaded above the preview and
below the focus overlays. `setPreviewCovered` is the single writer of its
visibility. A playing notification alone does not uncover video: the timeline
must advance beyond 0.15 seconds. Position notifications are requested every
0.1 seconds. The still covers the final 0.75 seconds before EOF (one quarter of
the duration for clips shorter than three seconds), then remains until the
position wraps and advances again. This handles loops without intervening
buffering/finished notifications. Buffering and finished events also request
cover. A 20-second covered-transition timeout removes the preview while
preserving menu input. Repeated cover requests do not reset that deadline.

The user observed a black flash with native looping and no visible fallback.
The previous state-only presentation path could not anticipate that boundary.
This correction deliberately trades a brief still-image pause for covering
the transition; it does not provide frame-perfect seamless motion. On November
15, 2026, the user confirmed on their device that the still now replaces the
jarring blank screen. Preserve this as the improved POC baseline while exploring
uninterrupted motion; this observation is not comprehensive device verification.
The older [Roku looping example](https://forum.developer.roku.com/t/looping-video/527)
uses a black canvas and recreates roVideoScreen, so it is not a gapless-loop
solution for this SceneGraph page.
Every new preview attempt has fresh node ownership; events from retired nodes
are ignored. A failed still produces a retryable page error.

History records screen transitions. Toggle artwork replaces the current screen
without pushing history. Back resolves historical audio/subtitle/Info Text
aliases against current preferences, then falls back to the disc root; Back
at the root with empty history exits. State resets when the demo reopens.

## Selection and ISO playback

Initial title, chapter, and audio come from `defaultSelection` when present.
Scanned manifests without it do not infer a title from catalog order or commands.
`playableTitles`, when supplied, limits content selections.
Subtitle and Info Text intent start off. Feature audio preference survives extra selection. Effective
audio uses the selected title's PGC mappings, choosing the preference when
available, otherwise its first available track, or no audio.
The default title determines the feature title set. Menu aliases come from
`menuMap.aliases`; settings actions honor their optional target screen, allowing
Raiders' three audio choices to retain its setup artwork. Unsupported and unknown
actions show a reason without substituting a title or posting playback. Asset,
menu HLS, and content endpoints use the selected disc ID. A new page per disc
resets menu state and preview failure caches; paths also include the disc ID.

Select and Resume call local `playSelection`. When `playbackAvailable` is true
and the manifest supplies `playback.schemaVersion = starfin-dvd-playback/0.1`,
the selection opens plugin 0.1.4 ISO playback. Absent capability/prerequisites
retain the title/chapter/track acknowledgment with an unavailable explanation.
Subtitle or Info Text intent blocks playback with an explanatory AppMessage;
neither saved preference is silently cleared. PDF screens remain artwork only.

The local selection snapshot still includes reviewed chapter/PGC metadata, but
the task sends only the contract's six fields: a fresh UUID `requestId`, global
`titleNumber`, one-based `chapterNumber`, logical `audioTrackNumber` (null when
absent), and the two subtitle/Info Text intent booleans. Outbound JSON uses
explicit camelCase keys through `Json` helpers. No file paths, PGC/program, or
approximate seek offsets are sent. There is no automatic POST retry. Resume
currently starts the retained title/chapter; it does not restore elapsed time.

`Helpers/Playback.bs` owns a separate fullscreen native Video surface following
the trailer-player pattern. It deliberately bypasses ordinary VideoPlayer's
Jellyfin item negotiation, queue, progress, and watched-state behavior. The
surface uses authenticated finite HLS, audio on, looping off, Live false, and
PlayStart zero to begin the selected chapter. No seek commands are issued.
Play/OK toggles pause; arrows/replay/seek keys are consumed by the page. Menu
preview audio stops before content starts. The menu tree, history, selections,
and hotspot remain retained; artwork and Spinner cover startup.

`DvdPlaybackTask` owns the complete HTTP session lifetime using captured session
authentication. It accepts the response session UUID in hyphenated or compact
form, case-insensitively: the installed Jellyfin serializer emits compact GUID
values while the plugin's route strings retain hyphens. It continues to validate
all response paths exactly against the known hyphenated request UUID,
preserves server base paths, and supplies MediaBrowser authentication. Heartbeats
run every 30 seconds after POST returns, including player startup, buffering,
and pause. POST and subsequent control requests have a 15-second timeout. The
task queries status on player failure or a 60-second startup/buffering timeout,
then deletes the session. Backend `completed` means encoding finished and does
not end client playback: only the Video finished event does that.

Back, natural EOF, failures, and page removal share cleanup. Video/timer ownership
is revoked before stopping; late events and responses are checked by node and
request UUID. Cancellation during POST lets the task finish and DELETE the known
session instead of force-stopping its thread. Cleanup continues after page removal.
Normal return waits for cleanup, restores the existing hotspot, and reopens the
original menu preview URL. Errors use AppMessage and restart the preview after
dismissal. Cleanup is best-effort if transport fails; server idle expiry remains
the backstop. No user-facing retries loop POST or change the selected tracks.

## Coverage and verification status

Rooibos coverage is grouped under the owning page and task suites, with Header
and MainScene regression cases. It covers geometry, state transitions,
authentication, request correlation, failures, selection payloads, preview
events, cleanup, and focus. Automation uses remote keys for the menu workflow;
network fixture setup can force preview failures before entry.
The automation suite requires the installed Robots of Death plugin on the
configured test account's server. It reads that server's manifest for directional
paths rather than injecting button events. The preview-failure proxy is scoped
to the test and the original session and badge preference are restored afterward.

The HLS integration and audio changes have source review only. Per the user's
experimental POC instruction, no test coverage was added or updated for them.
The plugin handoff reports 0.1.2 source complete but not built or deployed;
installed 0.1.1 manifests continue to use MP4 until the plugin is deployed.
Pending HLS checks include authenticated refreshes/segments, continuous audio
and video across repetitions, switching, fallback, and overlay alignment. A
musical cut already present in the excerpt is not necessarily a streaming gap.

POC diagnostics use the existing Logger with the `DvdPlayer` label. Preview
starts report the asset, chosen format, and client-loop flag; state changes
report live mode, position, and duration. Cover transitions report whether an
MP4 wrap is pending. Stops, error codes, and covered timeouts are also logged.
Player failures include `errorMsg` and `errorStr` before cleanup, with the session
token redacted. Native diagnostics may include the failing media URL; request
headers are not logged. These distinguish MP4 EOF cover
from HLS buffering before changing the confirmed still-image fallback again.
Rejected content-session responses log the HTTP status, parsed value type, and
response body under `DvdPlaybackTask`, with the session token redacted, to identify
wire-contract differences before changing session validation.

Implementation source/diff review is separate from verification. Tests, builds,
function-header/whitespace validation, automation, and real-device inspection
remain deferred until explicitly authorized. Device acceptance includes the
installed plugin, preview fallback, modal focus restoration, and highlight
alignment at both 1080p and 720p. The 0.1.4 content integration is source-reviewed
only, with no tests added or updated per the experimental POC instruction. Pending
device checks include exact chapter/audio selection, authenticated child requests,
finite EVENT-HLS start/end, pause/heartbeat, cancellation during startup, and exact
menu/focus restoration. This uses the plugin's fixed ISO fixture, not a DVD VM.
The two-disc picker and Raiders navigation additions are also source-reviewed
only. No test coverage changes, builds, validation, or UI/device checks were run.
The scanned-library migration has the same deferred-verification status. Pending
checks include library/title Back navigation, empty and removed libraries, missing
metadata, partial scans, generation refresh, and scanned-disc HLS/playback paths.

Metadata browser verification is deferred during the open POC development cycle.
No tests were added or updated for this iteration. Device review should cover
authenticated posters, grouped/disc selection, refresh and removal, session reset,
and focus/highlight placement at 1080p and 720p when explicitly authorized.
