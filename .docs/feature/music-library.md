# Music Library

The Music Library owns album and artist loading, server-side browse filters,
paging, rendering, and local focus recovery.

## Browse vocabulary

Music supports Album, Artist/Album (`ArtistAlbum`), Artist, Favorites, Decade,
and Genre through the shared `LibraryBrowse.Option` enum. Semantic ordering uses
`LibraryBrowse.SortKey`, and direction uses `LibraryBrowse.SortOrder`. Persisted
values keep their existing strings and are normalized on restoration, with an
unsupported value falling back to Album.

The Artist/Album semantic sort is translated in one shared path to Jellyfin's
`AlbumArtist,SortName` expression. UI labels remain separate from identifiers
so wording can change without altering persisted state or API requests.

## Album requests

Ordinary album browsing requests 100 items per page. Decade browsing supplies a
ten-year `Years` filter and requests 50 items per page so Jellyfin can return the
first filtered page with less DTO construction, response serialization, and Roku
parsing work. Both paths request only the additional album fields used by the
library: `SortName` and `AlbumArtist`.

Artist-scoped album requests additionally request `ProductionYear` and
`PremiereDate` because artist album rows render the release year.

`EnableTotalRecordCount` remains enabled because the library header displays the
server-reported item count before every page has loaded. The server may filter or
sort by fields that are not included in the returned DTO, so decade filtering
does not require returning the album date fields.

## Filter refresh and recovery

Decade and genre changes retain the last committed grid while a debounced page
zero request is active. Query identities reject obsolete responses, paging is
blocked during the transaction, and failures or timeouts restore the committed
view. Because the existing grid and filter controls remain usable during this
refresh, closing the browse overlay restores focus to the filter row immediately
instead of waiting for the asynchronous response.

Initial and reconciled album loads use the foreground loading path. Each
foreground album page has the same bounded request timeout as a transactional
filter refresh, owned by a separate timer so debounce and transactional refresh
state cannot redirect foreground timeout handling. A timeout stops the task,
invalidates the outstanding query, clears the blocking loading state, reports
the failure through the shared app status, and returns focus to the page
controls. A late response is therefore treated as stale instead of reopening
the completed loading transition.
