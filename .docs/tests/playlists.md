# Playlist Test Scenarios

This document covers manual validation of Jellyfin playlist display and playback
behavior.

## Test Data

Prepare the following Jellyfin data before testing:

- A Playlists library containing no playlists.
- A Playlists library containing exactly one playlist.
- A Playlists library containing multiple playlists.
- An empty playlist and a playlist containing non-playable entries.
- A mixed playlist containing movies and TV episodes.
- A playlist containing duplicate occurrences of the same movie and episode.
- A playlist with watched, unwatched, partially watched, and fully watched items.
- A playlist whose order differs from title, release-date, and episode order.

Run artwork scenarios with the Playlists system setting set to both `Poster` and
`Thumbnail`.

## Library Entry and Navigation

- Select Playlists from the Home page's My Media row and confirm the playlist
  page opens.
- With multiple playlists, confirm the top-level playlist list is displayed.
- With exactly one playlist, confirm its contents open automatically and the
  loading spinner stops when the items load.
- Select a playlist from the top-level list and confirm its contents are shown.
- Press Back from playlist contents and confirm the top-level playlist list is
  restored when multiple playlists exist.
- Confirm Browse, Sort, and A-Z controls never appear or receive focus in either
  playlist view, including during initial and automatic loading.
- Confirm ordinary video libraries retain their Browse, Sort, and A-Z controls.

## Layout and Artwork

- Confirm the default Playlists system setting is `Thumbnail`.
- In Poster mode, confirm playlist cards use Primary artwork.
- In Thumbnail mode, confirm playlist cards use Thumb artwork.
- Confirm playlist movie items use the expected poster and thumbnail artwork.
- Confirm playlist episode items use series/episode-appropriate artwork in both
  modes rather than the opposite aspect or a placeholder when valid artwork is
  available.
- Confirm missing artwork uses the correct placeholder without distorting card
  layout.
- Confirm the playback button group is flush with the right edge of the grid in
  both Poster and Thumbnail modes.

## Item Ordering and Duplicates

- Confirm playlist contents remain in Jellyfin server order, matching the order
  in which occurrences were added to the playlist.
- Confirm repeated movies and episodes render as separate cards.
- Confirm duplicate occurrences retain their positions after progress, watched,
  or favorite state updates.
- Select each duplicate occurrence and confirm it opens the expected media item.

## Playlist Playback Controls

- Confirm Resume, Play, and Random appear only for a loaded playlist containing
  playable movies, videos, or episodes.
- Confirm all three controls remain hidden for empty and non-playable playlists.
- Confirm Play and Random remain visible for a fully watched playlist while
  Resume is hidden.
- Confirm Resume appears when any playable item is unwatched or has saved
  progress.
- Confirm initial focus selects Resume when visible and Play otherwise.
- Verify left/right movement between controls, Down into the grid, and Up to the
  application header.
- Confirm button icons, labels, focus states, text centering, and optical padding
  are consistent across Resume, Play, and Random.

### Resume

- Confirm Resume selects the first playable occurrence not marked watched.
- Confirm it uses that occurrence's saved position.
- Confirm inconsistent watched/progress data falls back to the first playable
  occurrence.

### Play

- Confirm Play starts the first playable occurrence at position zero.
- Confirm subsequent items follow playlist order.

### Random

- Confirm Random shuffles all playable occurrences, including duplicates.
- Confirm it begins playback immediately.
- Confirm queue entries retain playlist identity and saved progress after the
  shuffle.

## Direct Item Playback

- Select a movie card and confirm the video player opens directly without first
  opening the movie details page.
- Select an episode card and confirm the video player opens directly without
  first opening the episode details page.
- Confirm the selected occurrence becomes the current queue item and retains the
  complete playlist queue.
- Stop playback and confirm the playlist page is restored rather than a movie or
  episode details page.
- Confirm focus returns to the occurrence that was last playing.

## Queue Advancement

Test each transition type with both the Next control and natural completion:

- Episode to episode.
- Episode to movie.
- Movie to episode.
- Movie to movie.

For every transition, confirm:

- The next playable playlist occurrence starts immediately.
- TV episodes do not switch to the show's normal episode order.
- No Up Next page or autoplay overlay is displayed.
- Queue order, queue index, series identity, season identity, and video mode are
  preserved.
- Stopping after advancing returns focus to the item that was last playing.
- The final playlist item closes through the normal player flow and returns to
  the playlist without an Up Next page.
- Ordinary non-playlist TV season queues still retain their normal Up Next
  behavior.

## Progress and Media State

- Confirm playback progress updates the hidden playlist grid while the player is
  active.
- Confirm watched completion, resume position, and progress indicators are
  correct after returning to the playlist.
- Confirm watched, favorite, and progress changes update every duplicate
  occurrence of the same media item.
- Confirm Resume visibility is recalculated after playback and reflects the
  updated watched/progress state.
- Confirm completing or skipping through several queue items focuses the last
  played occurrence when playback closes.

## Focus and Loading Regressions

- Confirm no Browse or Sort controls flash while a playlist is loading,
  including automatic opening of a single playlist.
- Confirm the loading spinner does not remain visible after success, failure, or
  an empty response.
- Confirm returning from playback does not move focus to Resume, Play, Random,
  the header, or the first grid item unless that was the last relevant focus.
- Confirm Thumbnail layout can move focus between the grid and all visible page
  controls.

## Validation

After code changes, run:

```text
npm run validate
git diff --check
```
