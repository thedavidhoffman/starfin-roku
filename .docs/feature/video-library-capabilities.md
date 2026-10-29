# VideoLibrary capabilities

`VideoLibrary` supports several library surfaces with different browsing behavior.
The capability matrix below documents the intended behavior for each surface.

| Surface | Browse By | Sort order | Letter grid | Filters | Ordering |
| --- | --- | --- | --- | --- | --- |
| Movie library | Yes | Yes | Selection-dependent | Yes | User-selected |
| TV library | Yes | Yes | Selection-dependent | Yes | User-selected |
| Collection contents | Yes | Yes | No | No | User-selected |
| Playlist library | No | No | No | No | Title ascending |
| Playlist contents | No | No | No | No | Playlist order |

Device automation exercises two configured Title-mode letter-grid cases for
each movie and TV library. Library names come from `MOVIE_LIBRARY` and
`TV_LIBRARY`; every filtered page is loaded and its sort names are verified.

## Selection-dependent letter navigation

The letter grid is available only when the active Browse By selection keeps
items ordered by title:

The active letter tile uses the same text color as a focused tile. `ALL` is
active when the grid first opens, and selecting another letter transfers the
active visual to that tile.

| Browse By selection | Letter grid | Reason |
| --- | --- | --- |
| Title | Yes | Items are ordered by title. |
| Favorites | Yes | Favorite items remain ordered by title. |
| Genre | Yes | Filtered items remain ordered by title. |
| Decade | Yes | Filtered items remain ordered by title. |
| Release Date | No | Items are ordered by release date. |
| Date Added | No | Items are ordered by date added. |
| Date Show Added (TV) | No | Shows are ordered by their own added date. |
| Date Episode Added (TV) | No | Shows are ordered by their newest episode addition. |

## Policy ownership

- `isPlaylistsView()` identifies the specialized `Playlists` component.
- `isPlaylistLibraryRequest()`, `isPlaylistContentRequest()`, and
  `isCollectionContentRequest(request)` identify request modes.
- `getVideoLibraryBrowseCapabilities()` owns Browse By, Sort, letter-navigation,
  and filter-option availability.
- `supportsLetterNavigation(selection)` determines whether the active selection
  is compatible with the letter grid.
- Request preparation owns fixed ordering, persisted view-state restoration, and
  filter reset behavior.

Collection contents support Title, Release Date, Date Added, and Favorites
browsing plus ascending or descending sort order while the collection remains
open. Collection browse state is not persisted, so reopening a collection uses
the request's ordering or the Title ascending default. Genre and Decade choices
are omitted because collection contents do not load filter options, and the
letter grid remains unavailable.

When Jellyfin groups movies or shows into collections, the corresponding movie
or TV library can contain `BoxSet` items alongside its normal media cards. These
cards display `Collection` as their secondary metadata label and open through
the same collection-content surface described above. Closing that surface
restores the originating library instance, including its loaded content, browse
state, scroll position, and focused card. Collections opened from the dedicated
Collections browser continue to return to that browser.

Movie detail Previous/Next browsing follows playable movie neighbors rather
than raw grid adjacency. Grouped collection cards are skipped, and paging
continues when necessary until another movie is loaded or the library ends.
Movie detail pages opened from collection contents use the same behavior,
skipping Series entries in mixed collections. TV Show detail navigation is not
changed.

Top-level Movie and TV library requests allow up to 120 seconds because Jellyfin
collection-query performance can degrade sharply when grouped collections are
enabled in large libraries. Starfin keeps the normal request payload, including
user data for progress and watched rendering. The shared HTTP default remains 60
seconds for collection contents, playlists, music videos, filters, detail pages,
and unrelated API requests.

Behavioral tests are the executable specification for this matrix. Update them
with this document whenever a library surface or browsing capability changes.

## Browse vocabulary

Shared browse identifiers are defined by `LibraryBrowse.Option`, semantic sort
keys by `LibraryBrowse.SortKey`, and directions by `LibraryBrowse.SortOrder`.
Video supports Title (`SortName`), Release Date (`PremiereDate`), Date Added
(`DateCreated`), Favorites, Decade, and Genre. Persisted identifiers retain
these existing string values and are normalized when restored, defaulting
unsupported values to Title.

Labels such as "Release Date" remain presentation text rather than enum values.
This keeps user-facing wording separate from Jellyfin and persisted-state
contracts.

TV libraries label the existing `DateCreated` choice **Date Show Added** and
offer **Date Episode Added** (`DateLastContentAdded`) immediately after it.
Both choices retain show cards; Jellyfin owns the date values and ordering.
Episode-added sorting uses the normal server-paged item request, with no local
episode fetching or sorting. Other surfaces retain **Date Added** and do not
offer episode-added sorting.

These TV choices apply when `collectionType` is `tvshows`, or when it is absent
and `includeItemTypes` is `Series`. Collection and playlist surfaces are excluded.
The active button and restored selections use the same context-specific labels
as the menu. Existing `DateCreated` preferences retain their saved identifier and
direction; episode-added preferences use `DateLastContentAdded`. An episode-added
selection supplied or restored on an unsupported surface falls back to Title.
Both date choices disable letter navigation, and changing to either clears the
active letter bucket. Episode-added selection and direction persist per account
and library through the existing view-state store.

The Browse By button widens from 190 to 300 pixels for either TV date choice.
Its label and background share the wider size. The page keeps the sort-direction
button anchored at the right edge and moves Browse By left, adjusting the heading
space to avoid overlap. Other selections return to the standard 190-pixel width,
including the generic Date Added choice outside TV libraries.

RTA coverage in `tests/automation/specs/tv-library-sort.spec.mjs` exercises both
TV date options in ascending and descending order, comparing every rendered item
ID across all pages with an independent read-only Jellyfin query. Separate cases
cover restoration after app relaunch, clearing an active letter filter, full-label
rendering without ellipsis, control/heading spacing, and shrinking back to Title.
Screenshots capture the wide labels and restored standard button.

The scenarios use the configured `TV_LIBRARY` and authenticated session, require
a nonempty library with an alphabetic sort name, and restore Title ascending after
each case. Keep library contents unchanged while comparing paginated results.
The existing resolution runner can exercise the same scenarios at each supported
resolution. Adding these scenarios does not imply they have been run.

Changing Browse By selects the new option's semantic sort key and resets its
direction to ascending. The committed selection synchronizes both controls and
the request snapshot so filtered reloads cannot retain a direction from the
previous browse option.

## Library heading placement

The library name and item count, Browse By, Sort, and the optional music-video
Random button share a top position of 132 px, moved down 12 px to improve their
placement between the app header and library grid. The heading retains its
natural height; the grid and filter row keep their existing positions.

The dedicated Collections browser also positions its centered heading at
132 px, down 12 px. It has no Browse By/Sort controls and retains its natural
heading height and existing grid position.
