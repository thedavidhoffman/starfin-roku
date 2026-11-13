# Trailers

Movie and TV series detail pages expose a Trailers action when Jellyfin metadata
indicates local trailers or contains a supported YouTube URL in `RemoteTrailers`.
The action uses the existing dynamic video toolbar in each detail layout, with
an outline filmstrip icon in the existing light and focused colors. The label is
"Trailer" when item metadata indicates exactly one supported trailer, otherwise
"Trailers". `trailerCount` is the toolbar's sole capability input: zero hides the action,
one uses the singular label, and larger counts use the plural. The count combines
local trailer count and case-sensitive deduplicated YouTube links.
The completed catalog remains authoritative for deciding whether a picker is needed.

## User flow

Opening Trailers fetches `/Items/{Id}/LocalTrailers` with the captured account
context and combines those items with the parent's YouTube metadata links.
Local items come first. Each source retains its server order. Local trailer
titles prefer the first nonempty `MediaSources[].Name` in server
order, falling back to the item's `Name`, then "Local trailer". This preserves
Jellyfin's media source title when its root title has been shortened. No filename
parsing or extra metadata request is needed.
Local IDs and
YouTube video IDs are deduplicated within their own source using case-sensitive
identity keys, preserving distinct YouTube IDs that differ only by letter case. No YouTube search is
performed, and other remote website links are not treated as playable media.

Catalog discovery shows the shared Spinner with the dialog frame hidden.
One candidate starts immediately without showing a picker or fetching row metadata.
Multiple candidates open a centered themed
dialog with a scrolling, three-row viewport. Each row shows a 320x180 (16:9)
preview and a 28px bold title wrapping to two lines. The channel/source line is omitted. Preview images use centered
fill/crop rendering with the existing resolution-aware rounded thumbnail mask;
missing or failed artwork uses the thumbnail placeholder. Cropping removes the
outer padding of typical 4:3 YouTube thumbnails, but cannot guarantee removal of
letterboxing baked into arbitrary artwork. Local Primary artwork URLs use the
shared image URL builder with the server's image tag and 320x180 dimensions, so
changed artwork produces a new URL when the catalog is loaded again.
YouTube oEmbed title metadata enriches rows asynchronously without resetting
selection. Channel/source display metadata is not carried through the catalog or
metadata responses; the source discriminator remains for playback routing.
Missing metadata and failed images retain readable fallback text and artwork.
The three rows start 36px above the default content origin, at 212px intervals,
using the gap below the title rule. Each rounded selection highlight is 204px
high, with 12px image padding on the top, bottom, and left. Titles align to the
preview top edge. The footer stays in its original position. Normal
picker guidance and loading/cancellation text are omitted. The shared Spinner
shows during catalog loading and stream resolution; Back still cancels. Empty-state
guidance remains in the footer without shifting the rows. The position counter is shown
only when there are more than three trailers; lists that fit in the viewport
have no count.
With exactly two catalog entries, the centered dialog height is 628px instead
of 840px, removing the unused third row's 212px spacing. Row dimensions and
padding stay the same, including when returning from playback. Three or more
entries retain the full-height scrolling picker.
No duration badge or additional duration request is included.

Playback is fullscreen with no pause, seek, captions, or transport controls.
For multiple trailers, Back stops playback and returns to the picker at its
previous selection; natural completion does the same. For a single trailer,
Back, completion, or failure closes the feature and returns to the detail page.
Single-trailer failures carry an error message in the overlay close result;
MainScene restores detail focus before displaying it through AppMessage.
Back from the multi-trailer picker
closes it and restores the Trailers button, falling back to the toolbar's normal
focus target if that action has disappeared.

Back while resolving cancels that attempt: single-trailer sessions close, while
multi-trailer sessions return to the picker. Back while
loading the catalog closes the feature. Empty results allow OK to reload.
Resolution and playback failures follow the same single/multiple return rule and
use AppMessage for acknowledgment. A local-catalog failure retains known YouTube entries but does not
autoplay from an incomplete catalog; closing and reopening retries discovery.

## Ownership and lifecycle

- `components/pages/Video/Trailers/` contains TrailerDialog, TrailerContent,
  TrailerListItem, TrailerPlayback, and YouTubeTrailerPlayback. The dialog owns the session state,
  correlation generations, selection requests, task lifetime, and local-stream
  cleanup. Content owns scrolling and focus; row components render entries.
  TrailerPlayback exclusively owns its Video node, timeout, and media controls.
  YouTubeTrailerPlayback owns ranked startup attempts and creates a fresh player
  for each attempt so queued Video/timer events cannot affect its successor.
- `components/tasks/Video/Trailers/` contains catalog, metadata, YouTube resolver,
  and local-transcode cleanup tasks. Local stream negotiation reuses
  VideoPlaybackInfoTask with the trailer item and an explicit zero start position.
- `source/Trailers.bs` owns source/state/overlay contracts, URL parsing,
  normalization, counting, and the overlay payload. `source/YouTubeTrailer.bs`
  owns the external provider's client profiles, case-preserving request JSON,
  bounded HTTP resolution. `source/YouTubeTrailerQuality.bs` owns manifest
  inspection, compatible progressive candidates, ranking, and URL deduplication.
  `source/TrailerPlaybackResult.bs` defines completion/cancellation/failure reasons.
- Detail pages pass explicit item/server/token/user context. MainScene routes
  the overlay and coordinates theme audio and return focus. OverlayHost invokes
  feature cleanup on ordinary close, replacement, and navigation teardown.

The dialog progresses through loading, choosing, resolving, playing, and closed.
`transitionTrailer` is the only state writer and derives dialog visibility,
resolution Spinner control, picker interaction/status, and focus from the state.
Playback buffering and its Spinner remain owned by TrailerPlayback.

Each selection receives a monotonically increasing `activePlaybackId` from the
session generation. `playStream(stream, session, playbackId)` and
`playCandidates(candidates, playbackId)` carry that identity; `ended` includes
`playbackId` alongside reason/message and, for child playback, `hasStarted`.
The optional identity defaults to zero for standalone callers. TrailerDialog
accepts completion only from its active player with the current identity.
YouTube fallback children retain the selection identity and must also match the
current child node. Local playback gets a fresh player per attempt; YouTube
continues to use a fresh child per fallback. Old Video/timer events remain tied
to stopped instances instead of affecting replay.

Release clears active player, identity, and local-stream ownership before stopping
or detaching nodes. Local encoding cleanup is dispatched once using the captured
session; repeated teardown and late completions are harmless. Dialog teardown
also stops pending tasks and detaches observers exactly once.

AsyncLifecycle accepts one result for the current attempt; consuming a response
invalidates it. Metadata uses the catalog generation so it can enrich rows while
a later playback attempt is running. Cancelled attempts cannot start playback.
Completed task nodes are pruned when starting more work; pending work is stopped
and observers detached on teardown. Fresh task nodes avoid restarting a Task
while its response callback is still executing.

Theme music is stopped for the entire trailer dialog. Late theme lookups are
suppressed while it is open. Normal closure restores the current detail item's
eligible theme after synchronous Video stop; replacement/navigation does not
restore the old theme. Acknowledgment focus restoration returns to the player
when it is active, otherwise to the picker.

Local playback uses JellyfinAuth's same-origin media authentication and the
existing device-profile negotiation. Cleanup issues a session-scoped
`DELETE /Videos/ActiveEncodings` after stopping the Video node. The cleanup Task
runs independently of picker teardown and has a five-second HTTP timeout.
Trailers do not issue playstate reports, modify the parent item's watched/resume
state, enter a queue, or trigger Up Next.

## YouTube compatibility

The implementation follows the direct Roku approach inspected in Moonfin's
Roku client, rather than relying on an external resolver service. YouTube's
internal player endpoint is not a stable public playback contract. Client
profiles and response handling are deliberately isolated for maintenance.

The resolver returns a ranked array of data-only candidates through
TrailerResolveTask's `candidates` field, with `ok` false for an empty result.
Each candidate includes URL, container, preferred audio language, and advertised
compatible height (zero means unknown). No function references cross this boundary.

The resolver tries VISIONOS then ANDROID. A playable result below 1080p does not
stop discovery: the resolver retains it and checks the next profile. A confirmed
1080p candidate ends discovery. A restricted/unusable response may retry once
with a fresh visitor identity. Player API calls have a five-second cap, manifest
inspection a two-second cap, all within the existing eight-second total budget.
Failure or deadline exhaustion returns the best candidates already collected.
Signed URLs and visitor identities are never persisted.

HTTPS HLS masters are inspected for complete H.264/AAC variants with advertised
resolution up to 1080p. The master URL is retained to preserve audio groups and
adaptive lower renditions. Progressive candidates require an HTTPS URL, H.264,
AAC, and a known height from 1 through 1080; cipher-only and video-only entries
are excluded. Candidates rank by compatible height, with HLS preferred at equal
height, and duplicate URLs collapse to the highest-ranked description. Unknown
HLS quality (an unavailable manifest or media playlist) ranks below known video
quality; malformed or demonstrably incompatible masters are rejected. DASH is
deferred until device compatibility is established.

1080p is a selection target, not a claim about the resolution currently decoded.
Roku still controls HLS adaptation; the master is not rewritten or filtered, and
its other variants remain available. Bandwidth/device behavior may select a lower
rendition, and a mixed master may include formats above the target. Inspection
establishes advertised compatible capability, not verified device playback.
Original-language metadata takes precedence over default-language metadata.

YouTubeTrailerPlayback tries at most three distinct ranked candidates. It advances
only on failure or timeout before the child has ever reached `playing`. Each
attempt retains the 20-second startup/rebuffer timeout. Back, natural completion,
closure, and any failure after playback starts terminate the session without a
retry. Intermediate startup failures do not show an acknowledgment; exhaustion
returns one final failure to the picker. Events from replaced players are ignored.
Local Jellyfin trailer negotiation, authentication, and cleanup retain their
existing path and receive no automatic quality fallback.

YouTube's response fields use its native camelCase contract. Jellyfin response
fields remain PascalCase. Outbound YouTube JSON uses the repository Json helpers,
not FormatJson. External requests never carry Jellyfin credentials. Resolver
failures are logged without response bodies, signed URLs, or tokens. Removed,
restricted, or unsupported videos fail visibly rather than selecting a different
trailer or attempting to bypass restrictions.

No automatic previews, YouTube search, SponsorBlock, YouTube captions,
external-app launch, or companion-service configuration is included.

## Diagnostic logging

The existing Logger writes trailer diagnostics to the console and log collector.
`YouTubeTrailer` records the 1080p target, client/attempt and request budget,
failed or malformed responses, visitor retries (without the identity), compatible
progressive count, HLS inspection/rejection, best advertised quality, and the
reason discovery stops. `TrailerResolveTask` logs request identity and the final
ranked candidate list (container and advertised height).

`YouTubeTrailerPlayback` records candidate count, selected attempt/container/height,
startup fallback, and the specific reason retry stops. `TrailerPlayback` logs
stream startup, Video state changes, numeric error codes, timeout, completion,
Back cancellation, and stop; `hasStarted` distinguishes startup from rebuffer or
post-start failure. Explicit teardown is visible as a stop rather than completion.

`advertisedHeight=0` means unknown quality, not zero-resolution video. Advertised
height describes candidate capability, not the current HLS rendition. Local
trailer descriptors may have no advertised height. No signed media URLs,
credentials, visitor values, raw provider responses, or raw Video error messages
are logged by these diagnostics.

## Coverage and verification

Rooibos coverage accompanies the parsing and candidate helpers, provider request
and stream logic, dialog transitions, picker rendering/navigation, playback
controls, task boundaries, toolbar/page integration, overlay payload routing,
and theme-audio suppression. Shared Spinner instances replace custom loading
labels during startup and rebuffering and stop on completion, cancellation, or teardown. HTTP and media boundaries are mocked where needed.
The test build substitutes only the trailer Video node through a dedicated XML
fixture; production TrailerPlayback scripts, dynamic player creation, and observer
wiring remain active. Catalog/resolution transport and local cleanup dispatch
are mocked at their side-effect boundaries. These tests do not establish real
Roku decoder behavior. Workflow coverage enters through catalog responses and
checks single/multiple return paths, playback identity and emitter matching,
fresh local replay, idempotent cleanup, and Spinner/focus transitions.
OverlayHost integration coverage removes and replaces active local-trailer
dialogs through the production host. A test-only TrailerDialog subclass replaces
task dispatch with idle response nodes and records cleanup requests. Real
SceneGraph response observers invoke production handlers, lifecycle transitions,
and player creation.
Repeated host closure and late completion must not dispatch cleanup twice.
The tests exercise cross-client quality improvement, HLS inspection, candidate
ranking/deduplication, bounded startup retries, cancellation, stale responses,
single-item return behavior,
partial catalog failures, metadata enrichment, and scoped local cleanup.

During the open development cycle, source/diff review is performed but no build,
automated validation, test, UI automation, or device check is run. When explicitly
authorized, run function-header and whitespace checks, production/test compilation,
the full Rooibos device suite, and applicable UI automation. Device acceptance
must cover both detail layouts, local direct/transcoded trailers, YouTube HLS and
progressive fallback, 720p-first/1080p-second discovery, exhausted and post-start
failures, audible original audio, picker focus, Back during each
loading stage, errors, and theme-audio exclusivity. Live provider compatibility
cannot be inferred from mocked tests or successful compilation.
