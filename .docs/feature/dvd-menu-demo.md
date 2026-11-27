# DVD library and native playback

Home's **My Media** row appends one **DVDs** card after plugin discovery succeeds.
It respects the Libraries-row visibility preference and is independent of the
account badge. There is no DVD header button or alternate entry when the row is
hidden. The local card has a stable identity, never enters Jellyfin library or
Recently Added requests, and restores focus when the DVD browser closes. Home
composes it with ordinary libraries regardless of response arrival order.

DVDs opens the transparent `DvdLibraryPage` inside the normal app shell. Catalog
loading starts only on entry: one enabled library opens directly; multiple
libraries appear in a four-column landscape grid with authenticated artwork.
Back from a multi-library drilldown restores the focused library card; Back from
a single library or catalog returns to the Home DVD card. The header and clock
remain visible. The library heading uses the same centered `LabelHeading` as the
movie/TV library, including its large bold font, theme color, and vertical position.
Inside a library, the heading is prefixed with `DVD: `; the chooser retains `DVD libraries`.
Titles inside a library use a fixed five-column poster layout. Both DVD grids use a
24-pixel vertical row gap in the 1080p design space, preserving room below title
and caption lines; horizontal spacing and card geometry follow the shared layouts.

## Plugin discovery and artwork

After login or saved-session restoration, `DvdDiscoveryTask` requests
`Starfin/Dvd/Info` with a 3,000 ms timeout, preserving the configured server base
path and existing `Authorization: MediaBrowser` authentication. Home does not wait
for discovery. HTTP 200 with a nonempty string `version` enables the DVD card;
no exact plugin-version match is required. Discovery confirms availability only,
not configured libraries or playback readiness. There is no `/Version` fallback.

`homeImageTag` is opaque: Starfin URL-encodes it into
`Starfin/Dvd/Images/Home?tag=<encoded-tag>&width=<physical-width>`. Home artwork is
requested directly, with no startup catalog fetch. A missing tag keeps the card
usable with local placeholder artwork. No random session query, polling, or
client ETag file cache is used. New tags are picked up on a new authenticated
connection; the plugin owns tag changes after upload/reset/default replacement.

404 means the endpoint is unavailable (including an older backend). Timeout,
network errors, 5xx, malformed success and unexpected responses are temporary
failures. Neither result is persisted; retry occurs on the next authenticated
connection or app restart. 401 uses session-expiry handling; 403 reports access
denied without expiring an otherwise working session. Both keep the card hidden.

DvdDiscovery owns task cancellation and generation/node correlation. MainScene
passes its session-scoped presentation to HomePage. Server/user/token matching
prevents stale availability or credentials from crossing sessions. Sign-out and
login routing reset discovery. Returning from playback does not rediscover or
rebuild the retained DVD browser; it refreshes only per-disc user data for saved
resume availability.

Home and library cards contain artwork without stretching/cropping. The plugin
serves its embedded default when no custom image is configured. Starfin's local
placeholder covers loading/failure; the earlier generated concept is not bundled.
Home and library images request width 441 at 1080p or 294 at 720p. Title posters
request 252 or 168 respectively. All remote images use the MediaBrowser header.
Optional authenticated-image support in shared cards replaces recycled Poster
nodes to isolate credentials and old loads; ordinary card rendering is retained.

The library chooser consumes supplied `artworkPath`; titles consume `posterPath`.
Feature-local validation accepts `Images/Home`, `Images/Libraries/{libraryId}`,
and `Images/Titles/{metadataId}/Poster`, preserving the supplied `tag` query before
appending width. The retired `Metadata/{metadataId}/Poster` route is not accepted.
Library responses replace old results; catalog selection is retained by library ID.

Deployment requires the new `/Info` and unified image routes. The backend handoff
states package 0.1.40 still has the old discovery contract. No backend build or
deployment was performed here. Source/diff review only: no test changes, builds,
automated validation, or device checks. Pending checks cover response ordering,
hidden My Media, absent tags, custom/default/failed artwork, session changes,
recycled cells, base paths, both resolutions, empty/multiple/removed libraries,
poster-route migration, and focus return.

## Metadata browser (plugin 0.1.29)

The browser displays a six-column, two-row poster grid with vertical scrolling,
below the app header. It shows the library heading and card labels, without a
focused-title overview/details block. Overviews remain in the data for future UI.
ScrollingLabel uses maxWidth=252; only the focused card scrolls overflowing text.
Title cards show the year on the left when present. Multi-disc cards also show
the disc count right-aligned on the same caption row; single-disc cards omit it.
The browser has no footer control hints or Options refresh action. OK opens the focused card and Back retains the navigation described above. Empty and failed libraries show page-owned retry instructions; OK retries an empty or failed result.

Discs are grouped only within the selected library by nonempty `metadataId`,
normalizing UUID case/hyphens. Missing metadata IDs produce individual disc cards;
names and provider IDs never merge groups. Groups retain catalog order and use
the first member's metadata. OK on one disc starts its native DVD session at authored first-play. OK
on a multi-disc group opens a top-level disc picker, sorting by disc number, then
side number, then case-insensitive name and ID. Positive numbers precede missing
values at each numeric level. The picker shows `Disc 2, Side 1`, `Disc 2`, or
`Side 1` according to available values; when neither number exists, it uses the name/ID
fallback. Missing or null `sideNumber` in older responses is treated as absent. Back dismisses
that picker to the same focused card. The disc picker uses an 800 x 590 dialog with a 680-pixel-wide list, five visible 72-pixel rows, and floating focus. Additional discs scroll naturally without wrapping; there is no right-hand detail label. Titles without matched metadata or posters remain browsable with the existing fallback name and artwork. The backend excludes missing ISOs from its results.

Posters use explicit session authentication and preserve the full `?tag=` cache key. The client appends `width=252` at 1080p or `width=168` at 720p to request the displayed pixel width instead of the full-size image, after validating the supplied metadata path.
A separate metadata-poster path validator permits only the plugin's UUID-scoped
Images/Titles/Poster route and tag query. Shared six-column mask/focus assets keep
artwork and native grid highlights aligned. Each recycled card creates a fresh
Poster and checks node identity before applying load events; missing, loading,
and failed artwork retain a local placeholder.

MainScene retains the hidden browser while DvdPlayer is open. Back from the DVD restores the app header and focuses the retained browser grid without fetching
library data or rebuilding poster nodes. Selection and scroll position remain intact.
Reopening DVDs from Home creates a new browser and fetches fresh data. Each successful library load replaces the groups and grid content rather than appending; entries removed by the backend disappear on that load. Entries are not filtered by metadata, poster availability, disc number, or side number.
Loading blocks selection until its correlated request completes. Closing a page
cancels its request and ignores stale responses. Authentication expiry follows
the existing task observation route. Account/session reset removes both pages.
Identify, scanning, and metadata configuration remain in Jellyfin administration.

## DVD title layout settings

DVD title grids use five poster columns. The column setting has been removed
from Settings > DVD and from SettingsStore defaults, account keys and normalization.
Previously saved `dvd-titles-layout` values are ignored; no registry migration is needed.
Folder cards remain four-column thumbnails.

Settings > DVD offers Menu highlights: Original DVD (default) or Rectangle.
The account-scoped `dvd-menu-highlights` key stores `original` or `rectangle`;
missing/invalid values default to original. MainScene passes an explicit
`useOriginalHighlights` boolean at player creation. Rectangle mode bypasses sheet
validation/loading entirely; original mode retains authored sprites and fallback.
Both preserve suppressed auto-action highlights and existing navigation. The choice
applies to all DVDs on this Roku for that account, takes effect on the next DVD
opening, and is not synced to Jellyfin or stored per disc.

DvdLibraryPage owns its fixed five-column shared grid spec. DvdPosterCard uses
matching masks, image dimensions, and poster request widths. The browser no longer
receives layout settings from MainScene. Deferred device checks cover five-column
layout at 1080p/720p, image/highlight alignment, remaining DVD settings navigation,
and unchanged folder navigation. No tests or builds were run for this change.

## DVD browse preferences (plugin 0.1.44)

Inside a DVD library, the shared Browse By and Sort controls offer Title and
Release Date, with ascending/descending direction. The controls form a right-aligned
group at the grid's visible artwork right edge for each column count, with an 8-pixel gap; the heading stays centered. The library chooser
hides them, and loading/error states disable them. Up from the first grid row
reaches Browse By; Left/Right selects a control; Up reaches the header. Down or
Back from a control returns to the grid. Closing Browse By restores that button.

DvdLibraryPage sorts the complete loaded groups in memory, with no library,
manifest, or title-details request when preferences change. Multi-disc groups
remain intact and preserve disc/side ordering. Sorting retains the selected group
by its stable key and returns focus to the activated control.

Release Date uses disc `premiereDate`, falling back to summary `metadata.premiereDate`,
then year if no usable full date exists. Calendar dates compare without timezone
conversion. Year-only values sort at the start of their year internally; cards
continue displaying only the year. Unknown dates/years stay last in both directions.
Equal dates use case-insensitive title ascending, then stable group identity;
Title sorting reverses names with direction and uses identity to break ties.
For TV, the date is the series premiere. Existing titles gain full dates on the
backend's next enrichment scan; older responses remain usable with year fallback.

The page uses LibraryViewStateStore under the existing server/user account key
and a `dvd:`-prefixed library ID. It saves option/direction immediately and restores
before the first title render. Invalid preferences default to Title ascending;
changing the browse option resets direction to ascending. Returning from playback
retains preferences, loaded cards, and selection; a separate user-data refresh
updates saved resume availability without replacing the cards.

The lightweight metadata summary is sufficient for browsing. Full `metadataPath`
requests are deferred until a future details UI needs them; missing overview and
other detail fields are acceptable. Provider runtime never drives DVD timelines.

Source/diff review only; no test changes or automated/device checks. Deferred
acceptance covers both sort directions, equal/missing/year-only dates, grouping,
registry isolation and restart restoration, remote focus, dialog cancellation,
loading/errors, playback return, absence of sort API calls, and 1080p/720p layout.

## Native DVD sessions (plugin 0.1.22)

This is a breaking client/server migration. The client accepts only
`starfin-dvd-disc/2`, `mode: native-session`, and `session.schemaVersion:
starfin-dvd-session/1`. The catalog, metadata, poster sizing, and retained library
browser stay unchanged. Static menu maps, local audio/subtitle selection aliases,
title/chapter playback selection, and the old playback endpoint are removed.
Opening a disc starts original first-play, including authored intros and language
choices. Authored audio choices are owned by libdvdnav on the server.

### Ownership

`DvdPlayer` owns the current session revision, command queue, focus, and visible
media. Feature-local `Rendering.bs` handles menu artwork, previews, and button
geometry; `MenuModel.bs` contains only aspect-ratio fitting. `Playback.bs` owns
finite Roku Video units and reports actual player events. `SessionContracts.bs`
names the native states, commands, and task events. No DVD helpers move to source.

`DvdSessionTask` owns the authenticated HTTP session lifetime: start, serialized
commands, status polls, 30-second heartbeats, and DELETE cleanup. `DvdDemoTask`
continues to load discovery and manifests. MainScene owns only routing and the
explicit server/token/user session handoff. Existing playback controllers and
watched-state flows are not involved. The old `DvdPlaybackTask` is removed.

### Lifecycle and commands

Each opening generates a new UUID and POSTs `{ "requestId": "..." }` to the
manifest's validated session start path. That identity also determines cleanup
when a start response is lost. Status, commands, heartbeat, and stop paths are
checked against that session. All URLs preserve the configured server base path.
Every API request and Video/Poster HTTP agent uses `Authorization: MediaBrowser`;
tokens never enter URLs. HLS ContentNodes also carry the authorization header.

The worker polls at approximately 400 ms between requests and sends heartbeats
while a menu, paused video, or still is visible. Only increasing revisions change
the UI. A single in-flight command plus a page-owned queue serializes remote/player
commands; obsolete queued revisions/playback IDs are dropped. Transport/server
failures retry at most twice after two-second waits, preserving the exact command
body and UUID. A 409 refreshes state before accepting another navigation action.
Actual EOF that arrives before encoding completes retains its identical complete
command and retries after polling while that playback ID is current.

Back hides visible playback controls first. During content playback/stills it requests returnToLastMenu; from menus/errors it exits the DVD, stops local players, and signals worker
cancellation. The detached worker is allowed to finish its request and DELETE the
session; it is never forcibly stopped. An authored stop also deletes the session
and returns to the retained library browser. Failed sessions display the server
error and close the session. OK on that error starts a fresh session; Back exits.
404/410/429 failures are not retried. No static interpretation fallback exists.

### Menus and remote controls

Menu snapshots reconcile background media separately from button overlays. Exact
image/HLS/MP4 source paths identify the background within the current session;
asset IDs and visual similarity do not establish equivalence. Declared sources
are stored separately from runtime HLS-to-MP4 fallback state. Unchanged sources
retain Poster/Video nodes, audio, position, timers, and failure/fallback state while
buttons, links, auto-action flags, selected focus, and display geometry update.

Menu-originated preparation keeps the background playing without a loading overlay.
Input remains locked through command acknowledgment. Changed sources stop the old
preview and retain its ready still until the replacement still loads; repeated
replacements cannot displace that ready fallback with an unfinished image. The new
preview starts after its still is ready to cover buffering. Replaced-node events
are ignored. Content playback clears menu media before presenting titles/trailers.
No background update itself activates an auto-action button.

Pending device verification includes unchanged-background audio/video continuity,
geometry changes, genuine source replacement, rapid unfinished replacements,
preview failure, repeated/stale snapshots, command locks, and menu-to-content
transitions. This change received source/diff review only, with no test changes,
builds, automated validation, deployment, or device checks.

Plugin 0.1.38 adds optional `menu.buttons[].autoAction`. Directional selection of
an authored destination with `autoAction: true` immediately sends the normal
`button` command using its ID, the current revision, and one new request UUID.
Missing/false flags keep normal OK activation. Auto-action buttons receive no client highlight, including when selected by a snapshot; their focus, directional links, and activation remain intact. Small buttons remain in the graph,
including self-linked destinations; no geometry or title heuristics apply.
Initial focus, redraws, polling, and replayed snapshots never activate buttons.

OK and automatic activation share one command path. Menu input is blocked while
a command is queued/in flight or navigation is pending, including the interval
between a new menu snapshot and its command acknowledgment. Retries retain the
same command UUID. An acknowledgment that leaves the session in a menu releases
the navigation lock even if its revision did not change. Normal revision/node
correlation and backend-selected focus handle the returned menu. Timed/forced
activation is outside this change. Source/diff review only; device verification
of The Aristocats, self-links, ordinary buttons, rapid input, unchanged-revision
acknowledgments, conflicts, and stale/repeated snapshots remains deferred.

Menus use `imagePath`, optional `loopPath` (preferred), and `videoPath` (fallback).
The live HLS preview has audio enabled, client looping disabled, and no seeking.
MP4 fallback retains the previous local looping/cover behavior. A failed HLS
preview can fall back to MP4; otherwise artwork and button controls remain.
Preview startup/buffering has a 35-second HLS or 20-second MP4 timeout, with no
rapid retry of failed live preview URLs. New menu artwork retains the previous
image underneath until loading completes. Node identity guards reject old events.

`sourceWidth`, `sourceHeight`, and `aspectRatio` define one fitted display rectangle
in the 1920 x 1080 design space. Both artwork/video and button coordinates use that
rectangle. The server's selected button is used when valid, otherwise the first
button. Arrows follow supplied neighbors locally; OK sends a button ID with the
current revision. No authored commands, forced activation, or title shortcuts are
interpreted on Roku. Options requests the authored DVD Root Menu (Title Menu is
the server fallback); this interrupts current media rather than resuming an exact
position. Back exits from authored submenus. During content playback, Back first dismisses visible playback controls.

### Finite content and stills

`starting`/`preparingPlayback` retains an already visible menu background while resolving menu navigation. A retained menu stays spinner-free during unresolved `starting`; authoritative `preparingPlayback` shows the loading spinner immediately over that background. Button-command responses are applied immediately by the existing task snapshot path. The backend waits up to 500 ms for navigation classification, not video readiness; slower navigation returns `starting` and normal polling supplies the eventual result. Ordinary menu outcomes do not trigger a playback spinner. When entered from content it keeps menu artwork hidden and retains the previous content Video node when available. Menu stills are used only for menu previews. Title/trailer startup and buffering keep the content surface visible, showing its retained frame or black with the loading indicator; they never reuse an earlier menu image. Starting a content unit clears the obsolete menu artwork.
A new `playbackId` starts HLS exactly once after the worker confirms the original
playlist is published. A 503 preflight waits two seconds before retrying. The
finite player disables looping, seeking, and native trick-play controls. It starts
at the beginning of each supplied media unit, not the HLS live edge.

Roku Playing sends `started`; forward position updates report `progress` at most
once per fifteen seconds while playing. Play/OK pauses or resumes locally and queues the matching
server command. Only Roku Finished sends `complete`; neither
`awaitingCompletion` nor `encodingComplete` advances the DVD on its own.
Duplicate EOF and stale events from replaced Video nodes are ignored. Player
failure reports `playbackFailed`; buffering timeout closes the session.

The Video node is retained across EOF/still rather than stopped or removed until
the next media/menu transition. Actual last-frame retention depends on Roku
runtime behavior and is not yet verified. Finite still completion uses the
server's `expiresUtc` via the existing DateTime helper, followed by a
revision-checked `stillComplete`; indefinite stills wait for Options or Back.
Heartbeats continue in both cases. No seeking, subtitle rendering,
angle switching, or watched-state updates are implemented.

### Verification status

Source and diffs only during this development cycle. No tests were added or
updated; previous static-navigation/playback tests describe the removed contract
and require replacement when test work is authorized. No build, compilation,
automated validation, deployment, or device checks have been run for this change.

Pending authorized verification: full applicable Rooibos/device suite and reachable
remote workflows; native first-play and language menus; actual EOF continuation
versus early encoder EOF; duplicate/stale commands; pause/resume and buffering;
finite/indefinite stills; Options menu interruption; Back/account reset during
start; capacity/404/410/409/503 handling; token/base-path authentication on every HLS
playlist, refresh, and segment; 1080p/720p highlights and retained browser focus.
Seamless transitions between finite media units are not claimed.

## Playback controls: transport version 1

The [agreed transport scope](dvd-playback-controls-handoff.md) supersedes the
Previous/Next proposal. The dedicated DvdPlaybackControls component displays a
centered Play/Pause button and available name/year metadata. The later additive
title-timing contract enables the informational timeline described below.
Previous/Next and custom chapter selection remain omitted.
Authored menus remain responsible for scene selection and audio choices.

Capabilities and current transport flags gate actions; absent fields disable them.
Pause is local and server-owned, with authoritative snapshot reconciliation after
acceptance or rejection. Accepted DVD Menu navigation stops old media, clears the
old playback identity, and follows the new native snapshots. The session task
includes its latest snapshot in command acknowledgments, including 409 refreshes.

OK/direction reveals controls without performing an action. Play toggles directly;
Options requests DVD Menu. Left/Right moves between Filter and Play/Pause; the
timeline never takes focus. Auto-hide is
five seconds while playing; pause/buffering keeps the overlay visible. Back hides
visible controls first, then requests returnToLastMenu during playback/stills. Plugin 0.1.27 restores its latest interactive menu and selected button, or performs Root/Title fallback if no checkpoint exists. Back from an authored menu exits. DVD menus hide the overlay;
Options can still request the authored menu when available. Overlay timers stop
on failure, exit, and cleanup. Standard player controls remain unchanged.

Source and diff review only; no tests changed or checks run. The plugin handoff
reports source changes only, without a newly published/deployed package. Runtime
pause/buffering, menu-from-pause, stale events, HLS authentication, remote focus,
metadata fallbacks, cleanup, and both resolution layouts remain unverified.

Playback Back requires the advertised returnToLastMenu capability and current
canReturnToLastMenu availability; hasMenuCheckpoint is informational, not a gate.
When return is unavailable, Back exits the DVD. In-flight commands temporarily
consume Back rather than interpreting a command lock as unavailable navigation.
The Options main-menu shortcut remains separate; the overlay has no DVD menu button. Both actions revoke old media
on acceptance and use current revisions/UUIDs. Restored audio/language registers
come from the backend checkpoint, rolling back later authored changes. Return
while paused and stale-event/focus behavior remain unverified on Roku.

## Automatic continuation and menu selection

The ?Continuing in? countdown display has been removed: false triggers made it
unhelpful. There is no countdown badge, UI timer, deadline reconciliation, layout
file, or generated countdown artwork. The unused shared ISO-difference helper
has also been removed. Starfin does not interpret `automaticContinuation` for UI.

Backend-driven timed menus continue advancing through the existing session
polling. Finite still screens retain `still.expiresUtc` and task-owned
`stillComplete`; indefinite stills retain their existing behavior. No Skip button
or new completion command is added. Same-revision polls no longer generate
countdown-only page notifications; command acknowledgments still supply snapshots.

Fresh DVD library entry explicitly selects the first sorted title. DvdLibraryPage
blocks focus/selection updates during loading and grid replacement, so the outgoing
folder index cannot leak into the title grid. Sort/layout changes retain the title
by key; playback return retains the grid; returning to the chooser restores its
selected folder.

Menu selection reconciliation distinguishes command acknowledgments from passive
snapshots. Successful button/menu-navigation acknowledgments restore the backend's
selected hotspot even when menu data and revision are unchanged. Passive updates
preserve local selection. Both paths reuse the background and never activate
auto-action buttons merely by restoring focus.

Source/diff review only. Deferred device scenarios include timed menu advancement,
finite/indefinite stills without a badge, unchanged-menu command acknowledgments,
background continuity, and retained library selection. No tests, builds, automated
validation or device checks were run for this removal.

## Playback overlay and informational title timeline

DVD controls match the standard library player's lower-screen layout: title at
[103,760], year/runtime beneath it, the 1714-by-12 timeline at [103,885], and
Play/Pause at [923,962]. The same white track/fill, 20-by-26 rectangular playhead,
elapsed/negative remaining labels, fonts, and full bottom gradient are used.
The top-right Clock remains visible with the controls. Playback Filters uses the
shared compact Media Info pill style at [102,970.5], with measured label width
and a 600-pixel cap. Left selects Filter; Right selects Play/Pause. The timeline
is nonfocusable and has no seek, scrub, preview, or remote transport action.

DvdPlayer's feature-local Timeline helper derives presentation only from the
accepted current-session snapshot and its matching active Video playback ID.
The server must advertise `capabilities.titleTimeline`, provide a matching disc
and positive authored title number, `titleTimeline.status: available`, and positive
finite `durationSeconds`. Version 2 supplies measured piecewise output-to-title
ranges; progress is available only inside a range. Equal title endpoints represent
a hold. Older linear mappings use finite `titleOffsetSeconds` plus Video.position.
Every replacement playback supplies its own mapping. Requested resume positions
and filter checkpoints are never substitutes for measured timeline coverage.

Existing one-second Video position notifications update only timeline presentation,
before the independent 15-second progress-report gate. Updates do not change
focus, restart auto-hide, refresh filters, or add requests. Paused/buffering video
uses its actual reported position without wall-clock extrapolation. Snapshot
updates can make timing available or revoke it without replacing the Video node.
Startup/preparation, missing/unknown mappings, origin-pending, unavailable timing,
menus/stills, playback failure and cleanup hide the timeline. Runtime-only
metadata remains when supplied. Older plugins therefore retain usable controls.
Stale node callbacks and older snapshot revisions cannot restore an old mapping.
Timeline availability logs once per playback ID or reason change, identifying the
failed client eligibility check or the backend status/reason. Position ticks do
not log while timing is available.

Back dismissal and auto-hide release child focus before returning to DvdPlayer.
The existing five-second auto-hide and filter spinner behavior are unchanged;
standard-player source and assets remain unchanged.

Source/diff review only; no test changes, builds, automated validation, deployment,
or device checks. Deferred acceptance: beginning/chapter/resume/filter origins;
same-title unit replacement and authored title changes; pending/available/revoked
mapping; missing or invalid data; paused/buffering updates; stale callbacks and
cleanup; remote focus and repeated show/hide; full Filter label and layout at
1080p/720p. Runtime verification requires a backend deployed with title timing.

## Saved DVD resume (plugin 0.1.53)

Disc-level `userData.resume` controls the Resume / Start over prompt after disc
selection. DvdPlayer owns the prompt and startup mode; the feature dialog uses
OverlayHost and the existing DVD list content with two visible rows. Cancel
returns to the retained library selection. The session POST sends `startMode`
(`normal`, `resume`, or `startOver`) with a new UUID. Both HTTP and asynchronous
`resume-unavailable` failures offer normal startup or Start over; neither choice
is inferred silently. Once a session snapshot is accepted, the initial startup
choice is consumed and subsequent error recovery uses normal startup; an earlier
Start over choice cannot clear newly saved progress again. Transport retries
retain the original UUID/body. Bookmarks and native checkpoints remain server-owned.

Each new playback ID starts HLS with `live=false` and `playStart=0`. The player
reports `started` after actual playback and reports advancing Video positions at
15-second intervals. Positions are playback-unit-relative, never title offsets
or HLS duration. Pause and authored menu navigation capture the current position
before pausing locally and include the playback ID; menu commands retain their
revision as well. Navigation rejection reconciles the local paused state.

On user exit, DvdPlayer captures the final position before releasing Video. The
session worker sends `stop` with that position before DELETE and retries the same
UUID/body on transient failures. Exit returns immediately to the browser. A session-specific completion node
notifies the browser after worker cleanup, preventing bookmark refresh from
racing the save without blocking navigation behind network timeouts. Pending
title selection waits for cleanup and refresh; folder navigation and Back remain
available. Browser deactivation releases the completion observer.
Forced page teardown leaves that cleanup to the detached worker. Completed media
is not saved again on exit; actual EOF still sends `complete`.

After playback, DvdLibraryPage refreshes library user data and merges it by disc ID
without replacing grid ContentNodes or poster images. A selection during refresh
waits for the response and is correlated by group key; failure offers retry on
selection rather than launching from stale bookmark availability. Account/session
context stays explicit and no user data is shared between accounts. Sorting
continues to use the retained groups without network requests.

Controls display optional `Runtime` from `playback.durationSeconds` only for
playable content. This is the DVD-declared full authored title duration, including
chapter-menu entry, not a timeline, elapsed position or provider runtime.

Source/diff review only. Deferred device acceptance: prompt cancellation and
multi-disc choice; missing/incompatible bookmarks at POST and later preparation;
resumed HLS position across playlist sliding; progress/pause/menu/exit saves;
exit during an in-flight command; identical retry bodies; natural completion;
authentication failures; account isolation; retained posters/focus and sorting
during bookmark refresh; runtime absence; layouts at 1080p and 720p. No tests,
builds, automated checks, deployment or device verification run for this change.

Deferred regression scenarios also include Start over ? playback/progress ? error
? OK recovery without clearing the bookmark; exit with a stalled request; cleanup
finishing before/after browser activation; folder navigation during cleanup; and
leaving the browser before cleanup completes. Source/diff review only.


## Original DVD menu highlights

Starfin uses only the active session's optional `menu.highlightSheet`, selected by
the server for the current menu context, stream, palette and button definition.
It does not choose scan variants from `disc.menuAssets[].highlightSheets` or read
the retired singular manifest field. There are no title-specific definitions,
manual installation paths or diagnostic-navigation dependencies in the renderer.

The feature-local HighlightSheet helper accepts `starfin-dvd-highlight-sheet/1`
with positive integral dimensions, a maximum 2048-by-2048 atlas, group 1, and source
dimensions matching the live DVD raster. It checks crop/destination bounds, live
button membership, and duplicate button/state entries. Sparse sprites are valid:
missing or invisible artwork falls back to rectangles. Null/absent descriptors,
unknown schemas, malformed data and unsupported groups also use rectangles without
interrupting navigation or playback. Server diagnostic matching remains server-owned.

The PNG uses existing authenticated, disc-scoped asset requests with the configured
server base path and MediaBrowser header. Poster decode/render dimensions preserve
the original sheet. A translated Poster inside a clipped Group selects the source
crop before the enclosing Group applies destination position and independent DVD
horizontal/vertical scaling. Alpha, aspect ratio and letterboxing are preserved.

Sheet identity is its immutable asset path and pixel dimensions. Selection changes
and mapping updates on the same sheet reuse the loaded Poster and update crops
locally, without reassignment of its URI or restarting menu media. When matching
artwork exists but is loading, both highlights stay hidden for up to two seconds.
After that wait, the rectangle appears while loading continues; a late successful
load replaces it with the original sprite. Rectangle mode, invalid/absent descriptors,
missing matching sprites and image failures show the rectangle immediately. The wait
belongs to the sheet load and does not restart on focus changes or reused snapshots.
Navigation and OK remain responsive, and loading completion uses the current button
and selected/activated state. Sprite and rectangle highlights never display together;
auto-action buttons stay unhighlighted.
An update with no buttons also reconciles highlight visibility, hiding any previous
sprite even when the loaded sheet is reused.

OK may display the activated sprite while sending the normal button command without
an animation delay. If activated artwork is absent, selected artwork is retained;
if neither exists, the rectangle remains. Command acknowledgment or rejection
reconciles the selected state with the current menu and focus.

Changing sheets, leaving menu state, failure and cleanup release the overlay and
its load observer and fallback timer. Only events from the current Poster in an active menu are
accepted, preventing stale artwork from appearing after transitions. Returning to
a menu loads its current session-selected sheet through the same fallback path.

Deployment requires the updated plugin and complete native helper, followed by a
normal library scan using `dvd-menu-h264-30fps-gop60-no-bframes-aac128-highlights/3`.
Scanner limitations or extraction failures yield rectangle fallback; there are no
frontend heuristics for missing, changing or delayed subpictures. Older plugin
responses without the session descriptor continue using rectangles.

Source/diff review only; no test changes, builds, automated validation, deployment
or device checks. Deferred acceptance includes multiple menus/discs and sheet
sizes, sparse sprites, selected/activated fallback, transparency and anamorphic
alignment at 1080p/720p, same-sheet focus/mapping changes without downloads, late
loads after sheet replacement, null/unsupported descriptors, image failures,
submenu transitions, background continuity and unchanged command behavior.


## Playback video filters

DVD playback controls offer a left-aligned Playback Filters pill and centered Play/Pause. Each session
starts with None; the choice is not stored in account settings. Authored menus and
highlight sheets remain unfiltered. The standard Jellyfin player is unchanged.

DvdFilterDialog opens centered through OverlayHost (1800 x 1000 in the 1080p
layout), preserving the shared title, divider and content well. Three API-ordered
category headings sit above equal-width columns. Each column has five 136-pixel
rows; the current 14 effects are all visible, with the shorter column's fifth slot
empty. Future filters beyond five scroll within their column. Rounded cards show
a top-aligned checkbox, name and wrapped description. Descriptions use the existing
SmallestSystemFont at 0.8 scale, with up to four lines within the available height.
Filter names use SmallBoldSystemFont at 0.85 scale, below the category-heading
size but above descriptions. All cards use fixed top alignment: the name starts at
y=21, checkbox at y=23, and description at y=59. This moderates the top inset
while preserving internal spacing. The description box is 81 pixels high before
scaling to retain bottom padding, with
the same wrapping width and four-line limit.
Short descriptions leave extra space below rather than moving the text and checkbox.
Card dimensions, column spacing and navigation remain unchanged. Long-description
fit remains deferred for device review at 1080p and 720p.

DvdFilterContent owns remote focus on its content Group, deriving card highlights
from the focused filter rather than waiting for a list animation. MarkupLists own
row virtualization/scroll positioning but do not independently consume remote keys.
Up/Down moves within a column; Left/Right moves to the nearest available row in the
adjacent nonempty column without wrapping. Initial focus is the active filter, or
the first effect when no effect is active. Refreshes preserve focus by filter ID,
even if a filter moves between categories. Disabled cards remain focusable for
reading but ignore OK. Background images stay loaded; focus changes only their
opacity and text contrast. Checkbox interiors remain dark blue and checks white.

The bottom-left status area displays instructions or capability/errors. A compact
Clear button sits bottom-right, with no None card. Down from the last filter reaches
Clear when enabled; Up returns to the last focused filter. Clear emits noFilter.id
through the same selection event as effects, and is disabled when already selected.
OK on an enabled effect or Clear dismisses the dialog; Back dismisses without a
change. Selecting the active effect simply dismisses without a request or spinner.

An actual selection opens a blocking, cancellable Spinner owned by DvdPlayer's
filter transition state. It covers acknowledgment and replacement buffering, not
just the command request. Other remote actions are blocked; Back exits DVD playback
and uses the existing cancellation/session cleanup path. The spinner releases when
the replacement is playing or paused, on rejection, or on a terminal/menu/still
transition. Rejections use AppMessage and keep the backend's accepted selection.
The dialog is not reopened automatically. The standard buffering spinner is suppressed
while this filter spinner is active, avoiding duplicate UI.

Identical presentation updates are suppressed, changed rows update in place and
catalog loading preserves focus. Routine progress commands do not dim choices:
selection intent queues behind progress and captures revision/position at dispatch.
Selection diagnostics log player-side acceptance or blocking state and setFilter dispatch. These are emitted only on
user selection or dispatch, not on periodic playback updates.
Toolbar focus stays on the chosen action during temporary disabling; disabled
buttons ignore OK, and their focus styling returns when they become enabled again.
Left/Right still moves only to enabled actions.
If the targeted playback has ended or changed, the intent is rejected locally.

DvdPlayer's Filters helper owns a session-scoped DvdFilterModel presentation/event
bridge, catalog requests, capability timer and selection intent. The dialog and
content only present data and emit intent; MainScene routes opening/closing.
DvdFiltersTask loads the authenticated Filters catalog on DVD startup, picker opening, or Options retry.
Names, descriptions, category ordering and filter IDs come from the new categories
and noFilter response. No legacy flat-array parser, hard-coded effect inventory,
or synthetic None choice remains. The three-category catalog is accepted atomically;
malformed responses show a retry message without partially replacing existing data.
Clear requires a loaded noFilter descriptor, but does not require shader capability.
Info is polled every two seconds while capability is checking and the DVD session
is active; polling stops once capability resolves. Transport failures are recorded
separately from the backend capability. Timeout/network and HTTP 5xx failures retry
the failed request kind after 5, 15 and 30 seconds, then stop automatic retries for
that failure sequence. A successful response resets the sequence; authentication
failures and confirmed unavailable responses do not automatically retry. Entry
points and effects remain unavailable after a failed request until confirmation
recovers, while active-effect Clear access remains. The same single-request guard
and timer own retries and two-second checking polls; DVD cleanup cancels both.
Closing the picker does not
cancel session-owned availability work; leaving/restarting the DVD does. Shader choices require available. All selections wait for playable content
and serialized transport availability. Closing the picker does not cancel an already submitted filter change. Catalog errors remain in the panel; command errors use AppMessage. Server base paths and MediaBrowser authentication are preserved.

The session task serializes setFilter with a UUID, current revision/playback ID,
and the actual Roku position captured at dispatch. Known capability/checkpoint
rejections are nonfatal. Rejections refresh state before another user attempt,
which gets a new UUID. Network retries preserve the exact UUID and body; explicit
pending replies are not resubmitted. After pending or exhausted uncertain transport
responses, status polling every two seconds matches filterChange.requestId until
accepted or rejected. Unrelated/null results never establish an outcome. When delivery
is uncertain and no matching acknowledgment arrives within 30 seconds, the task
ends and cleans up the DVD session, displaying a retry message. It does not invent
a rejection or resubmit a new UUID. An explicit pending reply or matching pending
status confirms admission and continues normal acknowledgment polling. filter.pending is
rendering lag and does not lock commands after acknowledgment. Existing session
polling resumes after acknowledgment. Back exits through the blocking spinner throughout acknowledgment and startup; shutdown still cancels polling and deletes the
session. Session expiration follows the existing recovery path.

Every actual filter change during title playback replaces the playback identity,
including shader-to-shader changes. No client restart flag is sent. Acceptance
releases the acknowledgment lock, but filter choices stay disabled while the
session is starting or the replacement is buffering. The existing snapshot path
loads the new playback ID/URL at position zero with the server pause state, without
seeking to the submitted old-player position. The spinner covers startup; the
picker remains dismissed. Backend checkpoint restoration may rewind up to 2.5 seconds.
Selecting the already selected filter is a local no-op and never waits for a new
playback ID. Rejected checkpoint changes retain the old player and selection.
Replaced-player events remain guarded by node/playback identity, progress belongs
to the new player, and stale queued playback commands are discarded through the
existing dispatcher. Menus remain unfiltered; the picker is also available from authored menus.

This requires the backend release that replaces streams for all title filter
changes. The backend handoff reports that implementation is not yet packaged;
the previous ZIP still changes shader-to-shader effects in place.

Source/diff review only. No tests added or changed, tests/builds/automated checks,
deployment or device checks run. Deferred acceptance: centered vertical layout and description fit at 1080p/720p;
selection dismissal, blocking-spinner Back exit before/after acknowledgment; remote browse/apply/Back and accepted checkmarks;
capability checking/unavailable/access failures and retry; focus during status
updates and buffering; replacement across all filter pairs while playing/paused;
same-filter no-ops, zero-based progress and old-player events; late acceptance,
late rejection, stale IDs and checkpoint failures; cleanup, expiry, and exit while
pending. Runtime filter availability depends on the deployed backend contract.

## State-based session polling

DvdSessionTask schedules status GETs separately from commands and heartbeats.
Playing (including paused) and awaitingCompletion use a two-second interval to
refresh measured timeline coverage before its initial roughly six-second window expires;
starting/preparingPlayback and menu-continuation evaluation pending use one second.
Menus explicitly waitingForInput disable periodic status GETs; commands still wake
the task and their response snapshots refresh state. Heartbeats remain active.
Scheduled menus use automaticContinuation.expiresUtc minus serverTimeUtc to set a
local monotonic deadline, without comparing server timestamps to Roku UTC. The
menuInstance, timerId and expiry identify the scheduled deadline; repeated snapshots
cannot postpone it. At expiry, subsequent checks use one second until navigation
publishes the next state. Null/malformed/unknown continuation data uses a two-second
fallback and is never interpreted as waitingForInput. Other stills and pending
filter acknowledgments also use two seconds.
Encoding-complete/awaitingCompletion does not mean the viewer has reached EOF.
Stopped, failed, cancelled, and closed sessions do not schedule further polling.

A new command wakes the task and is handled before a periodic status request.
Accepted create/status/command snapshots, including equal revisions and conflict
refreshes, reconcile the status deadline using the current state and menu instance. Older revisions do
not refresh that deadline. Routine progress responses can therefore replace the
need for periodic GETs. Local timeline ticks and buffering do not request status.
The existing 15-second playback-progress and 30-second heartbeat schedules remain
independent; heartbeat responses do not count as session snapshots.

The task waits until the earliest status, heartbeat, finite-still, or command-retry
deadline, and wakes early for command/cancellation events. Finite stills retain the
existing expiresUtc/stillComplete behavior; no countdown UI or automatic-menu
command is introduced. EOF conflicts preserve the original completion UUID and
retry after one second rather than spinning or waiting for steady-playback polling.
Existing transport retries and session cleanup remain unchanged. In-flight HTTP
requests retain their existing timeout/cancellation behavior.

Review is source/diff only. Deferred acceptance covers steady playback and pause
request counts; commands arriving during a wait; fresh/equal/stale snapshots;
startup, pending-to-input-only menus, scheduled deadlines, repeated timers and
menu replacement, older-plugin fallback, finite/indefinite stills; pending filter acceptance/rejection;
EOF before encoding completion; heartbeat deadlines; cancellation and terminal
states. No tests, builds, automated validation, device checks, or deployment run.

## Player ownership and reconciliation

Presentation reconciliation is separate from controls rendering. Media/session
handlers update state, then reconcile filter transition completion, timeline and
control data, spinner presentation, focus recovery and notices. Controls rendering
itself performs no focus changes or transition work. Presentation owns overlay
show/hide and auto-hide timing; the normal and blocking filter spinners have one
presentation owner. Existing remote behavior and filter-dialog return focus remain.

MenuNavigation owns directional input, local selection, backend selection and
auto-action activation. Rendering updates backgrounds, geometry and highlight
sheets without choosing selection. Artwork/atlas-only updates retain local focus;
new menus (including changed `menuContinuation.menuInstance` identities with
identical buttons), changed button definitions/selectedButton and successful command
acknowledgments restore backend selection. Button nodes are retained when their
geometry and display scale are unchanged. Auto-actions still trigger only from
user directional input, never rendering or reconciliation.
Menu instance UUIDs are compared independently of artwork identity. Same-instance
updates preserve local selection; missing or invalid instance IDs retain the
existing button/selection comparison for older responses.

MenuPreview owns authenticated HLS/MP4 playback, buffering/loop still coverage,
fallback/cooldown and stale-event cleanup. Rendering retains ready still artwork
and compares declared background paths independently of runtime fallback state.
Lifecycle owns final progress capture and the shared exit/restart/failure cleanup
path. It detaches/cancels the session worker before releasing Video; the worker
continues stop/DELETE and signals completion after the page leaves. Resume owns
only the startup choice and unavailable-resume dialog flow.

Source/diff review only; no tests changed or run, compilation, validation, deployment
or device checks. Deferred regression scenarios include unchanged-background menu
updates, artwork-only/atlas-only revisions, different menu instances with identical
buttons, missing instance IDs, changed geometry, command acknowledgments,
auto-actions, repeated image replacement, preview fallback and stale events,
paused filter replacement/rejection, repeated control show/hide, failure/restart,
and exiting during pending session creation or commands. Refactoring does not
change backend requests, polling intervals, timeline calculations or DVD commands.

### Measured title timeline (contract version 2)

The server advertises `capabilities.titleTimelineVersion: 2`. A `piecewise`
mapping supplies bounded `ranges`, each containing `outputStartSeconds`,
`outputEndSeconds`, `titleStartSeconds`, and `titleEndSeconds`. The player
interpolates only inside a supplied range using Video.position. Equal title
endpoints represent a hold; missing coverage hides progress. Pausing therefore
holds progress without a separate wall clock. Existing playback and disc identity
guards apply to every replacement stream. Linear mappings remain supported for
older servers. This display contract does not enable seeking or change polling.

Timeline precision is preserved from the HTTP response to interpolation: DVD
session requests use `ParseJson`'s `d` flag and timeline values use
`Number.ToDouble`. The double JSON option is supported from Roku OS 14.6.
Other HTTP callers retain their existing parsing defaults. A one-tick range at
long playback positions must not invalidate the surrounding coverage.

Three-column dialog review: source/diffs only; no test changes or execution,
builds, automated validation, deployment or device checks. Deferred acceptance:
all 14 effects visible, four-line descriptions at 1080p/720p, row alignment, overflow
beyond five, unequal/empty columns, Clear return focus/availability, disabled
choices, refresh/reordering by ID, catalog errors, and command rejection/buffering.

### Playback Filters entry points and menu selection

The dialog title and playback pill use Playback Filters. On an authored menu,
Play/Pause opens the picker without joining or changing its directional button graph.
A small nonfocusable translucent dark hint near the bottom reads
"Press Play/Pause for playback filters." It appears for five seconds on the first
eligible menu per DVD session, then fades out over 0.4 seconds. It does not repeat
on submenus. Opening the picker or leaving the menu hides it immediately; session
cleanup stops its timer/animation and resets eligibility for the next DVD session.
Content playback retains normal Play/Pause behavior. Options is not advertised or
used to open menu filters because fullscreen Video can invoke Roku's audio sidebar.
The hint and playback entry are visible only when capability is available, or when
an active effect must remain clearable after capability loss. Unknown/checking/unavailable states
otherwise hide them. The toolbar recovers focus to Play/Pause if its filter entry
is hidden. The pill retains measured sizing for its longer label.

The menu-origin picker explains: ?Applies when video plays. DVD menus are unaffected.?
Its command contains revision/filterId but no playback ID or position. Content
selection still captures the current playback identity/position at dispatch.
Both paths share request correlation, pending acknowledgment, rejection handling,
and the cancellable blocking spinner. A menu selection finishes on acknowledgment
without restarting menu media; its preference applies to subsequent title playback
in that session only. Same-menu evaluation updates retain the picker; a transition
away or to a different menu instance dismisses it. Back restores menu hotspot focus.
No saved user preference or mandatory launch prompt is introduced.

Deferred source-only acceptance: startup capability discovery/checking/failure,
active-filter Clear after capability loss, menu selection/clear/rejection, timed
menu navigation while the picker is open, return focus, content replacement,
cleanup with capability requests pending, and short/long-description balance.

Deferred hint verification: five-second display and fade, no submenu repeats, late capability availability, picker/menu transitions, session cleanup, and normal content Play/Pause. Source/diff review only; no builds or device checks.

### DVD library beta notice

Only title grids display a persistent, nonfocusable rounded
information card below the heading. Its title is "DVD playback is in beta" and
its description is "This feature is experimental. Compatibility varies by disc,
and you may encounter issues with DVD menus, navigation, audio, subtitles, or
playback. Some discs may not play correctly. Please report problems to help us
improve the quality of this feature."

The notice uses the existing glass-card artwork and normal light text, with no
dismissal or acknowledgment. Browse/Sort sits below the notice, right-aligned with
the displayed grid. The title and wrapped description are measured and vertically
centered as a group inside the 160-pixel card, with an eight-pixel gap. The fixed
five-column grid begins at y=450 using its normal card size and focus artwork.
Error and empty-state messages also sit below the notice. Returning from playback
retains the browser as before. Source/diff review only; text centering, remote
scrolling and 1080p/720p layouts await device verification.

The library-card chooser hides the beta notice and retains its original grid and
status positions. Layout is reconciled when loading a library as well as rendering
results, so entering or leaving a title grid does not retain the wrong notice spacing.

Deferred highlight-wait checks: fast loads without rectangle flash; slow loads revealing fallback at two seconds and accepting late artwork; failure and missing-sprite fallback; navigation/OK during loading; unchanged-sheet updates; replacement and cleanup with stale image/timer events. Source/diff review only; no tests, builds or device checks.

### Menu background reveal

Initial DVD loading displays the selected disc's metadata poster behind the spinner
when artwork is available. The library passes the selected group's poster path,
metadata identity, card dimensions and column count with either single-disc or
multi-disc selection. Startup uses the same authenticated URL, including its tag
and physical-pixel width (with the card's HD rounding), so Roku can reuse cached
artwork without requesting a larger version. The card's 309 × 464 poster and
five-column rounded mask are scaled together by 1.5× to display at 463.5 × 696 design
pixels, centered on screen with 192-pixel top and bottom margins
and scale-to-fit behavior. 65% opacity over black keeps the spinner readable.
Missing or failed artwork leaves the plain loading background. The StartupArtwork
helper releases the poster when the first menu is revealed or content becomes
playing/paused, and on still/error/cleanup. It never returns for later menu changes
or playback buffering. Image callbacks from released posters are ignored.

Deferred checks: enlarged poster sharpness and cache reuse, rounded corners at 1080p/720p,
authenticated image failures, Back during loading, direct/resumed content startup,
and absence of startup artwork during subsequent transitions.

New menu backgrounds load behind a page-owned presentation gate. Static menus
reveal when their still is ready. Video menus keep the spinner and an opaque
startup cover until the preview reports playing plus forward position progress;
the still remains decoded for fallback but is not flashed before the video.
For a background replacement, the previous ready still stays above the incoming
media until reveal instead of showing the replacement's temporary still.

The current menu highlight and filter hint remain hidden until reveal. Menu input
is blocked during this wait, with Back still available. Existing sheet readiness
and its two-second fallback wait independently determine which highlight appears.
Unchanged backgrounds reuse their reveal state and do not restart media or timers.
Readiness received during a retained-menu preparation state is remembered. Returning
to the same background releases the gate without requiring another image or video
event; replacement backgrounds and cleanup discard that readiness.
Preview failure or the existing startup timeout reveals the still immediately;
HLS-to-MP4 fallback remains available. Subsequent buffering and finite MP4 loop
coverage retain their existing still-image behavior. Content transitions and cleanup
remove the gate, artwork, and observers; stale media events cannot reveal a newer menu.

Deferred device checks: static and video startup, submenu replacement, same-source
auto-actions, slow/failed HLS and MP4, preview cooldown, navigation/Back during loading,
highlight timing, cleanup and late events. Source/diff review only; no builds,
automated checks, test changes, or device checks performed.

### Menu-to-content timing diagnostics

`Timing` log entries identify menu selection, task command send/response, each newer
snapshot published to the page, playlist wait start/end, Video creation/play request,
first Roku playing state, and loading-spinner visibility transitions. Session IDs join task/page events; command request IDs
join button requests and responses, and playback IDs join playlist and Video stages.
Command and playlist elapsed milliseconds include transport retries and retry delays.
Video elapsed milliseconds run from node setup to first playing; setupMs identifies
the setup portion. These are client-observed intervals, not backend execution-time
measurements or proof of the first displayed frame. Existing state logs show later
buffering/errors. No new polling, credentials, response bodies, or media URLs are
logged. Source/diff review only; capture and device verification remain deferred.

### Fresh timeline coverage at unchanged revisions

DvdSessionTask forwards accepted same-revision snapshots because measured timeline
ranges advance independently of navigation revision. Older revisions remain ignored.
The player's existing same-revision path replaces snapshot data and recomputes the
informational timeline without recreating Video, resetting controls, or clearing
pending commands. Title playback polls every two seconds; menu scheduling, 15-second
progress reports and 30-second heartbeats are unchanged. Unknown ranges remain
unavailable; data is never extrapolated or reused across playback identities.

Added source-level test coverage for same-revision forwarding, expanding coverage
through twenty seconds, older revisions, cancellation, polling cadence, unchanged
Video/controls/pending commands, identity changes and genuine mapping gaps.
Tests and builds have not been run. Deferred device acceptance: Revenge of the
Cybermen on Synology, first twenty seconds and several minutes of playback, then
stop/resume; confirm timeline stability and rejection of the previous stream's data.

### Recovery and current verification coverage

Manifest loading, native-session requests, and filter discovery forward expired
authentication to MainScene's existing account-scoped sign-in recovery. Requests
from detached players are ignored. Access-denied responses remain distinct from
expired authentication.

Filter catalogs follow the controlled three-category contract. Parsing/shape
failure uses the existing load-failure/retry presentation and disables effect
selection; it does not accept capability availability as catalog success. Retained
valid Clear data stays usable for an active filter. No compatibility layer or
additional catalog-validity state is introduced.

The obsolete demo-button, manual-menu-map, stub-playback and retired endpoint tests
have been replaced by current library/task/native-menu coverage. Remote automation
enters DVDs through My Media, exercises Browse By cancellation, and opens/closes a
selected native disc while checking retained title selection. It requires current
plugin discovery, a visible My Media row and a nonempty scanned library. The old
MP4 demo proxy is removed. Functional coverage includes Back recovery, authentication
handoff, rejected catalog loading, uncertain filter admission and late outcomes.
All new checks are deferred: no tests, builds, automated validation or device runs
were performed during this implementation.
