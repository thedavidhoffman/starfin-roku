# TV Season Browsing

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

## Episode cards and season actions

Settings > TV includes **Show season summary card in TV episode list**, an account-specific Off/On
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

Play pressed during a playback-target refresh retains one pending Play intent.
Repeated Play presses and activation reuse active or queued refresh work. Only a
new watched-state change supersedes it. The latest successful refresh consumes
the intent once and uses the usual Resume-before-Play selection. Background
refreshes never start playback by themselves. Failure, deactivation, a new series
load, or success with no playable target clears the intent. An explicit Play after
failure retries and starts playback once fresh targets arrive.

## Automated setting coverage

TV settings persistence tests independently save and verify On and Off for both
Show season summary card in TV episode list and Use Episode Images. Each case saves the opposite
value first, so it exercises a real change even when run alone.

TV season display tests flip the summary preference On and then Off in each list
orientation. They reopen Settings to verify the prior selection, reopen the same
season through normal navigation, check card presence and order in the visible
layout, preserve episode IDs, and capture screenshots for both states. These
checks are separate from registry persistence and the existing Home artwork tests.
