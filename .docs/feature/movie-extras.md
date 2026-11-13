# Movie Extras

Movie details offer Extras before Cast & Crew. Only one supplemental row is
visible at a time. Down from the toolbar enters the first available row; Down
from Extras enters Cast & Crew; Up reverses that order and then returns to the
toolbar. Empty rows are skipped. All navigation chevrons remain beneath the row.
In Cinematic, movie actions show Down; focused Extras shows Up and Down together
when Cast follows, or only Up without Cast; focused Cast shows only Up.
In backdrop and Poster, Extras shows only Down when Cast follows and Cast shows
only Up. These layouts hide the footer when only one row is available because
that row and the movie actions are already visible.

Poster centers the footer on the right-hand row viewport, including the layout
and content-group translations. Its center stays fixed while scrolling items or
switching Extras/Cast, regardless of item count. Other layouts center it on the
screen. A paired Cinematic footer uses a 12-pixel gap and centers the pair as a
whole; a single chevron returns to the same center.
Returning from playback or person details retains the active row and its item.
Entering from the toolbar explicitly starts at the first available row.

Extras use 320-by-180 landscape artwork, a single scrolling title line, and a
runtime line using the existing runtime formatter. Extras sort alphabetically by displayed title, ignoring case; sorting does not
mutate the server response or change the selected item identity. The item canvas is 360 by
264; with the 48-pixel heading offset the row occupies 312 pixels. Missing or
failed artwork uses the shared thumbnail placeholder. Title scrolling runs only
while focused. Artwork uses the standard rounded mask with a 12-pixel FHD corner radius and
a native HD variant. Native RowList focus uses a rounded outline on a matching
canvas, around the image rather than the text. A -4-pixel row spacing preserves
the 356-pixel stride; the wider canvas accommodates the screenshot-derived
24-pixel horizontal focus compensation. `scripts/generate-movie-extra-assets.ps1`
recreates the masks and focus outline. Focus alignment at HD and FHD remains
a device-verification requirement.

## Ownership

`MovieSupplementalContent` owns the supplemental region: extras catalog state,
row selection, horizontal selection retention, availability, and presentation.
It embeds the existing Cast and HomeRowList controls. Its local `Loading.bs`
helper owns correlated background task dispatch and completion, suspension, and
retry. `MovieExtraItem` owns only card rendering and title scrolling.

Movie supplies explicit session/movie request data and people. It positions the
region, owns focus transfer to/from the movie actions, and renders the footer
from region availability. Movie's local `Helpers/Layout.bs` owns named Poster,
Cinematic, and backdrop
geometry functions, the shared shell visibility update, and one footer path
separating direction selection from positioning. Layout changes and row
availability changes use that same path, resetting both arrows each time.
Movie routes extra selections through its existing
`playSelected` event; MainScene and VideoPlayer require no special extras path.
Poster retains the 1152-pixel viewport beside the poster. Other modes use 1848
pixels. Cinematic hides details/actions while the region has focus; other layouts
retain details/actions while showing one supplemental row.

## Loading and playback

`MovieExtrasTask` requests the authenticated
`GET /Items/{itemId}/SpecialFeatures?userId=...` endpoint and returns the array of
Jellyfin items with movie identity and request generation. Catalog identity is
the movie opened by the page, independent of its chosen playback version.
Trailers retain their existing toolbar flow; this feature does not fetch or
merge the separate local/remote trailer catalog.

Movie metadata requests include `SpecialFeatureCount`. Movie passes an available
count from the selected item immediately; if it is missing, the supplemental
component waits for the current movie-details response to resolve the count
before deciding whether to request the catalog. Fresh metadata also corrects an
initial cached count: positive starts a lookup even after cached zero, while zero
cancels an outdated lookup. Active or completed catalogs are not fetched twice.
Version-detail responses do not
replace the original movie's count. A failed metadata request releases this wait
and uses the unknown-count fallback.

- An explicit zero skips the catalog request and shows available Cast immediately.
- A positive count starts catalog loading but withholds both supplemental rows,
  chevrons, and Down navigation until the response completes. Movie actions stay
  usable. The reserved region stays blank, without a loading spinner.
  Successful results show Extras first; empty or failed results reveal
  Cast instead. Completion does not move focus from the toolbar.
- A missing count remains unknown, not zero. Once metadata has resolved without
  a count, fetch the catalog while keeping available Cast usable. If the user is
  already on Cast when metadata confirms extras or the catalog arrives, retain
  their focus and make Extras available above them.

The supplemental component owns the expected count, metadata wait, row hold,
and catalog-resolution state. Movie only supplies correlated metadata; row
visibility and navigation availability are derived together in `reconcileRows`.
New movie requests cancel the old catalog work and clear previous rows.
LatestRequestLifecycle generations reject stale completions, including repeat
visits to the same movie. Two alternating tasks allow pending work to start
outside the completing task's response rendezvous. Suspension cancels both tasks; unfinished work retries on activation. If movie metadata was
cancelled on departure, returning falls back to catalog lookup instead of waiting
forever for that response. Catalog failures are logged and retry on activation.
Once a catalog response has resolved the initial hold, retries keep Cast available
even before Movie restores supplemental focus after returning from a person page.

Remote Play on Cast remains unhandled here so Movie can play/resume normally.
OK or remote Play on Extras starts the selected extra from zero using its own item ID and
metadata. Extras are standalone: no inherited movie queue, version catalog, or
movie-specific stream indices. They use the movie's selected streaming mode
and the player's normal negotiation/default stream behavior. Progress tracking
is explicitly disabled for these clips; they do not update movie resume/watched
state or participate in automatic next-item playback. Normal player closure and
startup failure restoration return to the retained extra. Back on the detail
page retains the existing close-page behavior.

## Coverage and verification

Rooibos suites cover the task API contract, malformed/empty/failing responses,
card rendering and title focus, row navigation and missing rows, focus restoration,
late/stale/cancelled responses, retry, layout changes, playback isolation, and
movie routing/chevrons. Tests are authored but have not been run during the open
development cycle.

When verification is authorized, run production/test validation, the full device
Rooibos suite, and applicable UI automation. Exercise actual extra playback and
return (including failure), long titles, missing images, movie changes during
loading, Poster/Cinematic transitions, and native focus alignment at HD/FHD.
