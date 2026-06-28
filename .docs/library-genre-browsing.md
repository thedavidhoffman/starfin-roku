# Library Genre Browsing

This note documents the workflow and Jellyfin API calls needed to support
browsing a library by genre.

## Workflow

1. Open a Library page with the normal library request context:
   - `server`
   - `token`
   - `userId`
   - `libraryId`
   - `includeItemTypes`
2. Load the regular library items with `/Users/{userId}/Items`.
3. When the user chooses to browse by genre, request the genre list for the
   current library.
4. Display the returned genres as selectable options.
5. When a genre is selected, hide the genre view and reload the normal library
   item grid using the selected genre as a filter.
6. Selecting the default title browse mode clears the genre filter and reloads
   the normal library item list.

## Genre List API

Use Jellyfin's `/Genres` endpoint scoped to the current library:

```text
GET /Genres
```

Query parameters:

```text
userId=<current user id>
parentId=<library id>
recursive=true
includeItemTypes=<Movie|Series|Movie,Series>
```

Expected response shape follows Jellyfin's normal item-list pattern:

```text
{
  "Items": [
    {
      "Id": "...",
      "Name": "Comedy"
    }
  ]
}
```

Use `Name` for display text. Keep `Id` when available because it is the best
filter value for the follow-up item request.

## Filtered Library Items API

Use the existing library item endpoint and add a genre filter:

```text
GET /Users/{userId}/Items
```

Base query parameters:

```text
parentId=<library id>
recursive=true
includeItemTypes=<Movie|Series|Movie,Series>
fields=Genres,Overview,MediaSources,MediaStreams
enableImageTypes=Primary,Backdrop,Thumb,Logo
imageTypeLimit=1
enableTotalRecordCount=false
sortBy=SortName
sortOrder=Ascending
```

Genre filter:

```text
genreIds=<selected genre id>
```

If Jellyfin does not return a genre id, fall back to:

```text
genres=<selected genre name>
```

The filtered response can be rendered with the same item-grid code path as the
normal title browse mode.

## Implementation Notes

- Keep genre loading separate from normal library item loading. A dedicated
  task keeps the genre API request independent and avoids overloading the
  regular library task.
- The selected genre should flow back to the Library page as discrete data:
  `id`, `name`, and optionally the raw genre object.
- The Library page should own the final item reload because it already owns the
  item grid, selected movie/series routing, and current library request context.
- Clearing the genre filter should issue the same item request without
  `genreIds` or `genres`.
