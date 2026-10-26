# TV Season Browsing

The TV show page reads the independent TV Series preference and applies Full
Backdrop or Corner backdrop as selected, both on load and committed settings changes.
Cinematic is unavailable for series; existing saved values normalize to Corner
Backdrop. The Poster value places the series logo,
first metadata row, and horizontally centered playback toolbar near the top. A
four-column grid of larger season posters fills the space below, retaining labels, watched status,
and season actions. These posters use dedicated rounded masks at 1080p and 720p
instead of stretching the standard season mask. Cast and its chevron are unavailable in Poster layout.
Left and right chevrons flank the posters and appear only while season cards remain
offscreen on that side. Settings changes apply the page layout without reopening the series.

TV season pages retain their separate fixed presentation in this stage; future
season rendering will follow the TV Series preference. See
[Media Shell Layout Preferences](media-shell-layout.md).

TV season pages expose previous and next controls that update the existing page
while preserving focus on season navigation.

Season loading uses the shared `LatestRequestLifecycle` helper. The page keeps
one active `TVSeasonTask` request and replaces a single pending request whenever
the user navigates again while loading. Every request receives a monotonically
increasing `requestId`, which the task echoes on success and failure. Only the
latest generation may commit season and episode state.

The page alternates between two `TVSeasonTask` nodes. When an active response is
stale, the newest pending request starts on the idle node instead of attempting
to restart the Task that is still publishing its response. Intermediate season
selections are coalesced so rapid navigation settles on the final selection.

The task publishes primary season and episode data as soon as it is available,
then performs any optional series metadata or season-list work. A correlated
`tvSeasonComplete` response is published last. Primary data may paint without
waiting for optional calls, while only the terminal response releases the Task
lifecycle and starts pending work on the alternate node.

Each selection immediately renders its cached season label and previous/next
availability while clearing the prior season's episode cards. The shared spinner
uses its normal display delay, which restarts as navigation continues. This lets
quick traversal show season identity without flashing loading UI. If loading
outlasts the delay, the spinner remains active across stale work and is hidden
only after the current request succeeds or fails. Deactivation cancels both
tasks, clears pending lifecycle state, and hides the spinner.

Optional series metadata and season-list responses retain season-ID correlation.
They update the page only while their originating season remains current and
never clear the optimistically rendered season label.

## Single-season series shortcut

Settings > TV includes **Skip series page for single-season shows**, an
account-specific Off/On preference stored as `skip-single-season-series`. It
defaults to Off when no value is saved and follows the existing settings save
lifecycle. No migration is required.

When On, opening a series skips directly to its season episode list only when the
successful season response contains exactly one season with a usable ID. Specials
count like any other season: Season 1 plus Specials keeps the series page;
Specials alone opens its episodes. Empty series and multiple seasons retain the
series page. Loading errors retain the existing error presentation and Back path.

TVShow captures the preference as an explicit `skipSingleSeason` task request
flag. TVShowTask resolves it after loading series and seasons; an eligible
response carries `skipSeriesPage` and returns before Resume, Next Up, replay
fallback, or playback-queue requests. TVSeason owns loading the episodes once.
Ineligible series and playback-only refreshes retain normal playback loading.
TVShow accepts the correlated response and emits a season selection marked
`skipSeriesPage` before rendering series details. MainScene removes the skipped
series page before opening TVSeason; Back therefore returns to the original Home,
library, search, or person surface. Cancelled, superseded, and repeated responses
cannot trigger a later redirect. The preference is captured when a series opens;
changing it does not redirect an already open series. Explicit season/episode
entry and playback routes retain their existing behavior.

The TV settings remain on one page. **TV episode list scroll** and **Show season
card in episode list** share the top row, the shortcut occupies the middle row,
and artwork remains in the bottom row. Left/Right moves between the top cards;
Down from either reaches the shortcut, then artwork. Up from the shortcut returns
to the scroll card. The shorter season-card label preserves its existing registry
key and behavior.

## Episode cards and season actions

Episode titles use a native `ScrollingLabel` within the existing 531-pixel title
area in both horizontal and vertical lists. Like cast names, overflowing titles
scroll at 100 pixels per second while their card has focus (`repeatCount = -1`).
Leaving the card stops scrolling (`repeatCount = 0`); returning focus enables it
again. Short titles stay still. `TVEpisodeCard` owns this through its existing
`itemHasFocus` handler. Season summary cards continue to hide the title.
The component suite covers initial state, focus entry, exit and return, and title
replacement while focused.

Pressing **\* Options** on an episode opens the shared media-actions dialog above
the page, offering **Mark as Watched** or **Mark as Unwatched** according to the
episode's current state. This works in horizontal, vertical, and All Episodes
lists. The season summary, layout spacers, and season navigation do not open
episode actions. The dialog uses `watchedOnly` to omit favorites and navigation
actions; other media-action callers retain their existing choices.

Back closes the dialog without changing state and restores list focus through
TVSeason's focus-only interface, without reactivating the page or replaying retained
playback progress. Selecting an action uses the existing `MediaActionsController`
request/failure flow with
explicit session data. Successful results route back to TVSeason's canonical
watched-state handler to update episode cards and season counts and notify the
series page; Home playback rows are invalidated by the shared action flow.
The current episode selection is preserved if the viewer moves while the request
is pending. Either watched-state action invalidates retained playback progress for
the affected episode so later activation cannot overwrite the explicit change.
Whole-season changes also invalidate progress for episodes in that season; progress
for unrelated episodes is retained. Failures leave watched state unchanged and
show the existing error message. Component coverage includes list modes, eligibility, dialog options,
overlay routing, watched/unwatched updates, and selection preservation.

Settings > TV includes **Show season card in episode list**, an account-specific Off/On
preference stored as `show-season-summary-card`. It defaults to On for new and
existing accounts without a saved value. The setting follows the existing Settings
edit/save lifecycle and is included in System Info's account settings. No registry
migration is required.

When On, horizontal and vertical season lists begin with the season summary card,
including seasons with no overview or episodes. It retains the season artwork,
episode count, year, overview (with the existing series-overview fallback), and
whole-season watched indicator. Selecting it opens season details and season
watched actions; Play targets the first episode when available. When Off, the list
starts with the first episode. All Episodes remains episode-only with its existing
season grouping and layout spacers.

Cards use actual item IDs and `MediaItem.Type.Season` / `MediaItem.Type.Episode`.
Selection dispatches by type; initial episode targeting and focus restoration find
the rendered item by ID, with a type constraint for explicit episode targeting.
Playback queues contain episodes only, regardless of the visible card setting.

Saving either the card preference or list orientation rerenders retained data,
preserving item identity and existing focus ownership without additional requests.
Hiding a selected summary selects the first episode; an empty list falls back to
season navigation when available, otherwise the page. Updates beneath overlays or
inactive pages do not take focus. Initial entry keeps focus on the page while episode data is pending, then focuses
the first card (season summary when enabled, otherwise the first episode). Only a
confirmed empty list uses the empty-season focus fallback, including on reactivation.
When returning focus to the page without episode items, the page explicitly releases
its focused child so a hidden list cannot retain focus. Down from season navigation
during loading follows this same path, and Back remains available.
Explicit previous/next season navigation continues to retain navigation focus. Empty season details hide playback actions and focus
an available toolbar action; watched-action focus is resolved by button identity.
Other toolbar callers retain playback actions by default, including TVShow
refresh/retry behavior. Unrelated settings do not rebuild the list, and
pending responses render using the latest preference.

On the TV show page, pressing * while a season card is focused opens the existing
Media Actions dialog with Mark as Watched or Mark as Unwatched for that season.
OK continues to open the season's episodes; no additional options hint is shown.
The action uses the shared MediaActionsController and its existing error handling.
Only successful changes update the cached season and its watched badge. Dismissing
the dialog restores the season grid's focus and selection.

A season is fully watched when its UnplayedItemCount is zero. Marking it unwatched
restores the known episode count, or a nonzero fallback when no count is available.
The detail surface supports typed Season and Episode items. Whole-season watched
changes update the cached episodes and publish the resulting season count through
the same notification path as individual episode changes.

Successful watched actions invalidate Home playback rows so returning Home reloads
Next Up and Continue Watching. TVShow invalidates cached Play/Resume targets when
season watched state changes, including changes returned from episode details.
It refreshes Resume, Next Up, and the playback queue without reloading series or
season cards, changing selection, or taking focus. Requests use the shared
LatestRequestLifecycle and alternating Task nodes; newer changes supersede older
responses. Deactivation cancels pending work and a dirty playback target refreshes
on activation. Failed refreshes leave stale targets unavailable and show the
existing message dialog; selecting Play or reopening the series retries.

Series Play keeps Resume first, then Next Up. When both requests succeed with
no episode, TVShowTask resolves a replay target using season-scoped Episodes
requests with `Limit=1` and `IsMissing=false`. Regular seasons are tried in season
number order, continuing past seasons without an available episode. Season-zero
Specials are tried only after all regular seasons are exhausted. Seasons without
IDs are ignored; unknown season numbers remain eligible after numbered regular
seasons and before Specials. Jellyfin supplies the episode order within a season.
Each season starts at `StartIndex=0`. Replay advances one item at a time past
malformed entries and episodes without IDs. In regular seasons it also skips
episodes whose ParentIndexNumber is zero, because Jellyfin can interleave Specials
into regular-season episode lists. An empty page advances to the next season,
resetting the index; request failures stop resolution. Specials are eligible only
when processing the Specials seasons. Unknown episode season numbers remain
eligible. Replay starts from zero without
resetting watched flags, and uses the existing queue anchored to that episode.
This avoids downloading and sorting the complete series to select one episode.

The task response preserves `upNextItem` as the actual Next Up result and adds
`playItem` for the resolved Play target. Initial loads reuse the seasons already
loaded by the task. Playback-only refresh requests pass the page's cached seasons
explicitly; callers without season context load seasons only if replay resolution
is needed. An explicitly empty season list resolves to no target without episode
requests. Fallback requests retain SeriesInfo, People, and UserData.

Fallback loading runs only when successful Resume and Next Up requests are empty;
a request failure must not be interpreted as a fully watched series. A failed
season or episode request stops fallback resolution instead of bypassing that
season. Initial fallback failures are logged while series browsing remains
available. Refresh failures retain the existing retry behavior and structured
error information. An empty series still has no playable target.

Play pressed during a playback-target refresh retains one pending Play intent.
Repeated Play presses and activation reuse active or queued refresh work. Only a
new watched-state change supersedes it. The latest successful refresh consumes
the intent once and uses the usual Resume-before-Play selection. Background
refreshes never start playback by themselves. Failure, deactivation, a new series
load, or success with no playable target clears the intent. An explicit Play after
failure retries and starts playback once fresh targets arrive.

## Automated setting coverage

TV toggle persistence tests independently save and verify On and Off for
Show season card in episode list and Skip series page for single-season shows.
Each case saves the opposite
value first, so it exercises a real change even when run alone.

TV season display tests flip the summary preference On and then Off in each list
orientation. They reopen Settings to verify the prior selection, reopen the same
season through normal navigation, check card presence and order in the visible
layout, preserve episode IDs, and capture screenshots for both states. These
checks are separate from registry persistence and the existing Home artwork tests.

## Whole-series watched toolbar

After series details load, the existing VideoToolbar shows Mark as Watched for
unwatched or partially watched series, and Mark as Unwatched for fully watched
series. The order is Play/Resume, Mark as Watched/Unwatched, Play Random, then
All Episodes, matching the watched action's position after playback on other
detail pages. Selection immediately submits one WatchedTask request for the series ID,
using the same recursive server behavior as the library Options action. There is
no confirmation dialog or per-episode mutation loop.

TVShow owns the pending mutation, monotonically increasing request ID, and explicit
session context. Repeated presses are ignored while pending. Only a matching
successful response commits series and season data. Failure preserves prior state
and shows AppMessage; a new press retries. Navigation and new loads cancel pending
work, and obsolete responses cannot update the page.

Success updates existing season ContentNodes without rebuilding the grid, clears
cached playback and random queues, and refreshes Play/Resume targets. If the
random request was still running, its obsolete response cannot repopulate the
cache or launch playback; subsequent requests use a new generation. If the
watched action still owns focus, focus moves to its replacement action. Moving to
another toolbar button while the request is pending preserves that button's focus.
TVShow emits watchedStateChanged with itemId and isWatched; MainScene marks Home playback
rows dirty and routes the change to the library.

Aggregate refreshes include series and seasons and request refreshWhenCountHidden
so toolbar state remains correct when numeric badges are disabled. Older snapshots
are cancelled before a whole-series commit. Returned server aggregates reconcile
canonical data and the toolbar, including changes made in season/episode pages.

The toolbar owns focus mapping between Mark as Watched and Mark as Unwatched,
including background aggregate reconciliation. Updating watched state preserves
another focused action and does not pull focus into an inactive toolbar.
TVShow uses one local random-request cancellation helper for new loads,
deactivation, and whole-series commits. It stops pending work, clears its identity
and loading state, and dismisses its loading spinner. Callers own cache lifetime:
deactivation retains the random queue; new loads and whole-series commits clear it.
Watched request producers and consumers share WatchedAction.Command, preserving
the existing MarkAsWatched and MarkAsUnwatched request values.

RTA watched-toolbar coverage exercises both mutation directions with count badges
enabled and disabled, persisted server episode state, preserved season selection,
and reopening. Background aggregate responses also test watched-action replacement
and preservation of another focused button. Tests snapshot and restore individual
episode user data; see [Automated Device Testing](automated-device-testing.md).
