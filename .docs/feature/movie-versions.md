# Movie Versions

Movies with multiple distinct, nonempty Jellyfin `MediaSources` IDs expose a
Versions category after Video in Media Options, on movie details and in the
player. Choices retain server order and use the original movie catalog's source
names, with numbered labels when a name is missing. Loading individual-version
details refreshes source metadata while preserving those labels, even when the
response supplies a filename as the source name. Single-source movies and
episodes retain their existing options. Opening a movie anew selects the first
server source; choices are not
persisted in account settings.

## Metadata and selection

`MovieVersions` holds the original movie identity, complete source catalog,
selected source ID, and cached details for each loaded version. Movie details
load the first source's item when its identity differs from the movie. Playback
from other entry points initializes the same context during playback resolution.
`MovieTask` and playback resolution share the `JellyfinMovie.Load` API operation.
The selected item's streams, duration, chapters, trickplay, and UserData describe
that version. Original movie identity remains the navigation/event identity;
timeline requests use the selected version identity. `CacheDetails` updates
cached metadata without selecting a version; `Select` changes only selection.
Movie owns a single path for applying watched and progress updates to the cache
and refreshing the displayed selected item. Watched operations capture the
movie identity, selected source ID, and a monotonically increasing request ID.
WatchedTask echoes optional correlation fields on success and failure. Movie
accepts only its pending operation; a new load or deactivation invalidates it.
Completion updates the captured version's cache, refreshing the toolbar and
focus only if that version remains selected. The API target and high-level
watched event retain the original movie identity.

If the initial selected-version load fails, loading ends and the existing
acknowledgment is shown. The page and Back navigation remain available. Media
Options can still open and load a version through the existing Versions list;
Play remains guarded until the selected version has usable metadata. Tracks
and chapters are unavailable until that metadata loads. Loading the same source
refreshes the dialog and commits its newly available metadata on Back. There
is no additional retry control or automatic navigation.

The dialog owns uncached version loads through a bounded pair of MovieTasks and
LatestRequestLifecycle. Session data is explicit. Progress appears locally;
failure retains the prior completed draft and displays an app acknowledgment.
Stale responses and responses after closure/replacement cannot commit. Back
during loading applies only completed selections and stops pending loads.

Selections remain local until Back. Each visited version retains its own stream
and chapter draft; returning to the original version restores its original
choices. First switching to another version clears chapter intent, resets audio
to the source default and subtitles to Jellyfin Account Default, and preserves
explicit Off. Video mode remains shared across version drafts. Information and
available categories refresh for the pending source; playback diagnostics appear
only for the source actually playing.

## Commit and playback

Detail-page commits apply the version and tracks together. Resume uses that
version's UserData, including zero for an unwatched version; Restart uses zero.
The summary and runtime update immediately. An explicit chapter starts that
version with the final pending options. Movie Resume selections carry no
explicit start position, allowing playback resolution to read the selected
source's saved position after loading its metadata. Restart, chapter launches,
and player restarts retain explicit positions. Home and playlist movie Resume
launches follow this contract; unwatched movie deep links do as well. Watched
movie deep links retain their existing explicit zero position.

Player commits combine a version change with other options into one correlated
restart. The destination uses the captured elapsed time, bounded by its duration,
or an explicitly selected destination chapter. Prior playing/paused state and
Media Options focus restoration survive resolution and recovery. Accepted state
changes only after a playback response is accepted. A failed or missing source
does not silently select another version.

`mediaSourceId` and `movieVersions` travel with the playback request and accepted
response/restoration snapshot. Negotiation selects responses by ID and narrows
its working source list before subtitle URL/delivery calculation. The full
catalog stays separately available. Source-specific progress updates the cached
version without overwriting another version's visible resume state. Returning to
details restores the accepted version and tracks until the next movie load.

## Verification

Rooibos coverage includes catalog labels/order, source projection, resume data,
category/focus behavior, draft change/revert, track reset/Off, asynchronous failure
and closure, initial source loading, combined restart, duration bounds, chapter
override, paused restoration, pending recovery, and negotiation source matching.
Device verification also covers multi-source movies, source-specific chapters
and trickplay, playing/paused switches, and return-to-details retention. The
existing episode Media Options automation remains a regression check.
