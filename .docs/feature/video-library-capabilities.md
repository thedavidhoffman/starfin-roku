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
browsing plus ascending or descending sort order. Their selection is persisted
per collection. Genre and Decade choices are omitted because collection contents
do not load filter options, and the letter grid remains unavailable.

Behavioral tests are the executable specification for this matrix. Update them
with this document whenever a library surface or browsing capability changes.
