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

## Selection-dependent letter navigation

The letter grid is available only when the active Browse By selection keeps
items ordered by title:

| Browse By selection | Letter grid | Reason |
| --- | --- | --- |
| Title | Yes | Items are ordered by title. |
| Favorites | Yes | Favorite items remain ordered by title. |
| Genre | Yes | Filtered items remain ordered by title. |
| Decade | Yes | Filtered items remain ordered by title. |
| Release Date | No | Items are ordered by release date. |
| Date Added | No | Items are ordered by date added. |

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

Changing Browse By selects the new option's semantic sort key and resets its
direction to ascending. The committed selection synchronizes both controls and
the request snapshot so filtered reloads cannot retain a direction from the
previous browse option.
