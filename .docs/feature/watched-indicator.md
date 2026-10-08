# Watched Indicators and Unwatched Episode Counts

Settings > Current user > Theme contains side-by-side Watched indicator and
Show unwatched episode count cards below the theme choices. Their widths follow
the measured headings so trailing space is equal, with a 16px gap. Left/Right moves between badge cards, Up returns
to the theme choices, and Left from Watched indicator returns to categories.

- **Subtle** (default): original black badge with a white check mark, with its
  interior made fully opaque.
- **High contrast**: opaque progress-fill gold (#E2A44C) with a black check mark.

Both images are 58x58, retain smooth transparent outer corners, and use the same
existing component sizes and positions. Poster focus spacing is independent of
style. Media types that suppress watched badges stay unchanged. Optional remaining
episode count styles are configured independently in the neighboring card.

The code key is SettingsStore.Key.WatchedIndicatorStyle and the registry key is
watched-indicator-style. Values are subtle and high-contrast, represented by
WatchedIndicator.Style. The setting lives in the existing per-account registry
section; absent or invalid values resolve to subtle. No migration is required.

SettingsContent emits watchedIndicatorPreviewRequested only after selection.
SettingsDialog forwards it through OverlayHost to MainScene. MainScene owns the
active global watchedIndicatorStyle; MediaStatusBadge observes it and chooses the
shared image for media cards, TV season cards, and episode posters. Existing
badges update without rebuilding library content.

Normal dialog close saves the account preference through the existing settings
flow. Cancellation restores the current session preference. Login/reset restores
Subtle, account loading applies that account's saved choice, and preview events
are ignored while login is visible. Theme previews do not change the badge style.

## Remaining unwatched episodes

Settings > Current user > Theme contains **Show unwatched episode count**, with
Off, Subtle, and High contrast choices. The default is Off for existing and new accounts. This
preference applies to Series and Season artwork on every surface that already
supports watched badges, including season summary artwork in episode lists.
Individual episode cards retain their watched checks, even when their artwork
uses a series image.

With Subtle or High contrast selected, positive Jellyfin
`UserData.UnplayedItemCount` values appear as exact numbers on a rounded
background. Subtle uses white numbers on opaque black. High contrast uses
black numbers on opaque progress-fill gold (#E2A44C), matching the high contrast
watched graphic. Count style and watched-check style remain independent.
Its height, top inset, and right edge match the existing badge. The background
widens leftward to fit the text, supporting one, two, three, and larger digit
counts without abbreviations. Text placement centers the measured natural text
bounds from a separate unattached label, so previous render translations cannot
feed back into subsequent count layouts. Placement uses a 2px downward optical
adjustment for balanced numeral margins. Each count background reuses its matching watched check's
58px alpha mask, with uniformly scaled corners and a horizontally stretched
middle so corner geometry follows badge height rather than digit count.
A zero count shows the selected watched check.
Absent, negative, or malformed counts fall back to existing watched behavior.
Content that explicitly suppresses indicators suppresses counts too.

`MediaStatusBadge` owns numeric/check presentation and observes the global
`showUnwatchedEpisodeCount` preference. The width and height in its input describe
the original square badge footprint; its internal count group expands leftward. Consumers
assign one complete `data` object containing `eligible`, `isWatched`, and
`unplayedCount` (using -1 for an unknown aggregate), plus `width` and `height`.
This replaces individual state and dimension fields and delivers one consistent
state/size update. Missing data or missing/nonpositive dimensions hide the badge
without numeric layout. Size and placement remain owned by the cards.

The watched check is a plain Poster owned by MediaStatusBadge. A dedicated
watched-style observer updates its image through `WatchedIndicator.GetImageUri`
without invoking numeric rendering or measurement. Both preferences are applied
during initialization, including when the check is hidden. No separate
WatchedBadge component is required.

Shared video cards record the badge size while applying card layout, then publish
badge data after `renderPresentation` establishes the final geometry. Raw-data
updates reuse that retained size. Season cards supply 42x42 and episode artwork
supplies 57x57 in the same object; translation stays on the owning card.

Visibility and count colors/graphics update independently of numeric layout.
Each badge retains one layout keyed by count, width, and height, plus one text
measurement keyed by count and height. Equivalent data skips numeric layout;
width-only changes reuse measured bounds. Count or height changes remeasure.
Subtle/High contrast changes update colors and graphics without measuring again.
Caches remain local and bounded, survive hidden/check/Off transitions, and are
reused when the same count and dimensions return. Hidden size changes are applied
when the count becomes visible. No render API, timer, or shared global cache is
introduced.

The unattached measurement Label is allocated only for the first visible positive
count and retained for later measurements. Off, suppressed, and watched-only
badges do not allocate it.

`UnwatchedEpisodeCount.GetCount` accepts only Series/Season API integer counts.
Content replacement rebinds raw-data observers so recycled cards cannot retain
a previous item's count.

`TVEpisodePoster` accepts only `itemContent`, using its `HDPosterUrl` for artwork
with the existing thumbnail placeholder when empty. Its fixed 531x300 layout
keeps the 57px badge at [462,9] and the 513x15 progress track at [9,276].
Content replacement and clearing update artwork, progress, and badge state;
the raw-data observer follows the current content for live watched/count updates.
There are no image override, size inputs, or render/refresh interface functions.
Initialization processes already assigned content, while an empty initial
control leaves artwork unset until content is supplied. Clearing previously
assigned content displays the placeholder and hides progress and badges.
Library card sizing remains independent of this season episode artwork control.

The persisted key is `SettingsStore.Key.ShowUnwatchedEpisodeCount`, with registry
key `show-unwatched-episode-count`. Values are `off`, `subtle`, and
`high-contrast`, represented by `UnwatchedEpisodeCount.Mode`. The earlier `on`
value reads as Subtle to retain an enabled preference; new saves use style values. It is per account and requires no migration.
Selection previews travel through SettingsContent, SettingsDialog, and
OverlayHost to MainScene, the sole global preference writer. Focus movement and
loading settings do not preview. Closing commits through the existing settings
flow; cancellation restores the current account's committed preference.
Login and reset restore Off.

### Count freshness

Jellyfin aggregate user data remains authoritative. Library, Home, Search, TVShow,
and TVSeason own refresh requests through their local
`UnwatchedEpisodeCountRefresh` child. Requests pass explicit server, token, user
ID, and current items. The refresher deduplicates Series/Season IDs and fetches
aggregate user data in batches of at most 50, without loading child episodes.

Refreshes run when relevant content is displayed, when a page returns from
navigation/playback, after watched changes, and when the preference is enabled.
Switching between Subtle and High contrast changes presentation only; it does not
request counts or supersede active/pending refreshes. Disabling still cancels work,
and enabling from Off refreshes the complete retained snapshot.
While numeric badges are enabled, season count mutations wait for server totals
instead of deriving counts from local episode lists. Existing local episode
progress and watched-state updates remain in place. Season notifications publish
only validated server totals while counts are enabled. Missing or malformed
totals remain unknown, rather than telling the parent series page that the
season is fully watched.

Latest-request generations reject stale results, including repeated requests
for the same item. Paired tasks allow pending refreshes to start without
restarting a Task that is still publishing its previous result. Cancellation,
account/destination changes, and disabling the preference invalidate active
work. A failed refresh retains the last server snapshot without an additional
modal error. A later refresh retries. Returned counts and server-supplied aggregate watched state merge into the owning
page's current data and existing content nodes without rebuilding lists or
moving focus; unrelated metadata, favorite state, and local progress are retained.

### Library refresh overhead

VideoLibrary retains a complete loaded-item snapshot for full refreshes on
activation, initial display, and count preference enablement. Watched changes
target only loaded Series/Season aggregates identified by the changed item and
its SeriesId/SeasonId. Playback updates request these counts only when the local
played state changes; position-only updates and favorites do not fetch counts.
Unknown parents wait for the next full refresh. Removing a favorite updates the
retained snapshot without requesting counts. Appended library pages likewise
update the snapshot without refetching counts already supplied by the page load.

The refresher accepts optional `itemIds` alongside the complete `items` snapshot.
Enabling counts ignores that subset and uses the complete snapshot. Overlapping
targeted requests carry active and pending IDs into the newest generation,
filtered against the current loaded aggregates and isolated by session context.
Outstanding full refreshes remain full. `snapshotOnly` updates retain current
items without starting work; cancellation still clears retained and queued work.
Other pages continue using the original full-refresh contract.

Library responses are indexed by ID, then canonical and displayed arrays are
traversed once each. Only validated changes to aggregate count or server-provided
boolean Played state are merged. Duplicate occurrences and separate displayed
metadata are preserved; each changed cache key is notified once. Identical
responses produce no raw-data notifications, and grid content/focus are retained.
Changed aggregate results publish their replacement raw object in one assignment,
without clearing the node first. Existing in-place watched/favorite/progress
mutations retain forced notification through the clear-and-set path.
Badge input batching and numeric-layout caching additionally reduce work when
cards are recycled or their presentation updates.

### Deferred playback persistence follow-up

Playback stop reports are asynchronous. A count refresh triggered by local
playback completion or page activation can finish before Jellyfin saves that
report, leaving the displayed aggregate stale until another refresh. This does
not change server watched state. A separate playback lifecycle change should
keep stop-report ownership alive after player removal and trigger an aggregate
refresh after confirmed persistence. That change is deferred from this feature;
no persistence-completion signal or automatic retry is currently implemented.

### Settings navigation

Theme choices occupy the full-width top card. Watched indicator is the left
badge card; Show unwatched episode count is the right badge card. Right from
Watched indicator enters the count choices, and Left returns, preserving the
option row where possible. Down from the last theme choice enters Watched
indicator. Up from the first option in either badge card returns to Theme.
Captured editor focus restores the appropriate badge card after save failure.

TV settings retain their original single-page layout: TV episode list scroll,
Show season summary card in TV episode list, and TV artwork in "Next Up" and
"Continue Watching", in that order. There are no TV page indicators or fades.

Functional coverage includes batched badge inputs, layout/measurement reuse,
count sizes, style independence, eligibility,
content recycling, aggregate refresh correlation/cancellation/failure, settings
persistence and previews, Theme card navigation, restored TV layout, and
page-owned count application. Device
font metrics, nine-patch rendering, and focus behavior require the explicitly
authorized end-of-cycle runtime/UI checks.
