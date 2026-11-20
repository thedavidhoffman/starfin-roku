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
Titles inside a library use the account's DVD titles poster-column preference (3-6, default 6). Both DVD grids use a
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

Settings > DVD contains Title columns with just 3, 4, 5, and 6 buttons (default 6).
Poster presentation remains fixed; no Poster/Thumb/Detailed controls or unavailable
placeholders are displayed. The existing account-scoped `dvd-titles-layout` value
is preserved, using the normal SettingsStore save/cancel behavior. Unsupported
presentations fall back to Poster with six columns. The old DVD row has been
removed from Settings > Libraries.

The same DVD category offers Menu highlights: Original DVD (default) or Rectangle.
The account-scoped `dvd-menu-highlights` key stores `original` or `rectangle`;
missing/invalid values default to original. MainScene passes an explicit
`useOriginalHighlights` boolean at player creation. Rectangle mode bypasses sheet
validation/loading entirely; original mode retains authored sprites and fallback.
Both preserve suppressed auto-action highlights and existing navigation. The choice
applies to all DVDs on this Roku for that account, takes effect on the next DVD
opening, and is not synced to Jellyfin or stored per disc.

DvdLibraryPage receives settings explicitly from MainScene, including updates to
an already open/retained page. It applies shared poster grid sizes and focus assets;
DvdPosterCard applies matching masks, image dimensions, and physical-pixel poster
request widths. Layout changes retain the selected group and sort without fetching
the library again. Folder selection remains four-column thumbnails.

Three-column cards follow the shared poster presentation: the grid starts at the
shared 207-pixel top position and the year/disc-count caption is hidden to keep
the title within the screen. Other column counts retain both caption values.

Deferred device checks include all four sizes at 1080p/720p, image/highlight
alignment, settings navigation and save/cancel, account restoration, open-page
updates, and unchanged folder navigation. No tests or builds were run for this change.

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

`starting`/`preparingPlayback` retains an already visible menu background while resolving menu navigation. When entered from content it keeps menu artwork hidden and retains the previous content Video node when available. Menu stills are used only for menu previews. Title/trailer startup and buffering keep the content surface visible, showing its retained frame or black with the loading indicator; they never reuse an earlier menu image. Starting a content unit clears the obsolete menu artwork.
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
Previous/Next and title-timeline proposal. The dedicated DvdPlaybackControls
component displays a centered Play/Pause button and available name/year metadata.
Previous/Next, custom chapter selection, and a title progress bar are omitted.
Authored menus remain responsible for scene selection and audio choices.

Capabilities and current transport flags gate actions; absent fields disable them.
Pause is local and server-owned, with authoritative snapshot reconciliation after
acceptance or rejection. Accepted DVD Menu navigation stops old media, clears the
old playback identity, and follows the new native snapshots. The session task
includes its latest snapshot in command acknowledgments, including 409 refreshes.

OK/direction reveals controls without performing an action. Play toggles directly;
Options requests DVD Menu. Directional presses keep focus on the single control. Auto-hide is
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

## Compact playback overlay

DVD controls use a single bottom row: the shared 75-pixel Play/Pause button at
the left, with the title and an optional year/runtime line alongside it. Missing
metadata is omitted without a dangling separator; the title centers vertically
beside the button when both year and runtime are absent. There is no timeline,
scrubbing affordance, or reserved timeline space.

The existing soft bottom gradient is fitted into the bottom 280 pixels of the
1080p design layout. The shared Clock uses the standard player's top-right
position and styling. It is a child of the controls overlay, so clock and controls
show/hide together and remain hidden on authored menus. Remote behavior and
the five-second auto-hide remain unchanged. Standard player components and
artwork are unchanged.

Both Back dismissal and auto-hide explicitly release the overlay's Play/Pause
child focus before returning focus to DvdPlayer. Hidden controls do not consume
directional input or reacquire focus. Repeated DOWN → dismiss → DOWN and timed
auto-hide → DOWN cycles remain deferred device acceptance scenarios.

Source/diff review only; gradient contrast, long titles, missing metadata, clock
visibility and layout at 1080p/720p await authorized device checks.

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
locally, without reassignment of its URI or restarting menu media. Until loading
succeeds, or on image failure, rectangles remain visible. Sprite and rectangle
highlights never display together; auto-action buttons stay unhighlighted.
An update with no buttons also reconciles highlight visibility, hiding any previous
sprite even when the loaded sheet is reused.

OK may display the activated sprite while sending the normal button command without
an animation delay. If activated artwork is absent, selected artwork is retained;
if neither exists, the rectangle remains. Command acknowledgment or rejection
reconciles the selected state with the current menu and focus.

Changing sheets, leaving menu state, failure and cleanup release the overlay and
its load observer. Only events from the current Poster in an active menu are
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
