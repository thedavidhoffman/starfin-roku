# TMDB Filmography

Starfin uses The Movie Database (TMDB) to display a person's combined movie
and television acting credits. Jellyfin supplies the person and their TMDB
identity, while TMDB supplies the combined filmography data that Jellyfin does
not expose in the form required by the Filmography page.

## Availability

The Filmography button appears on a person page only when both of these values
are available:

- A TMDB API key is configured in Starfin Settings.
- The Jellyfin person contains a TMDB entry in `ExternalUrls` whose trailing
  URL segment identifies the TMDB person.

If either value is missing, the button remains hidden. The API key is stored as
the `tmdb-api-key` integration setting and is passed to the Filmography page as
explicit request data.

Users obtain and manage their own TMDB API key. Starfin does not proxy TMDB
requests through Jellyfin.

## Request Flow

Selecting Filmography emits a request containing the person's TMDB ID, display
name, image URL, and configured API key. `MainScene` mounts the Filmography page
in the dynamic page host and returns focus to the person page when Filmography
closes.

`FilmographyTask` requests the person's combined credits directly from TMDB:

```text
GET https://api.themoviedb.org/3/person/{personId}/combined_credits?api_key={apiKey}
```

The task validates that the person ID and API key are present before making the
request. The page correlates responses with the active person ID and ignores
responses from an obsolete or deactivated request.

## Credit Selection and Ordering

The Filmography page uses entries from the response's `cast` collection. Crew
credits are not displayed.

A credit is included only when it has:

- A movie `title` or television `name`.
- A usable date from `first_credit_air_date`, `release_date`, or
  `first_air_date`, in that priority order.

Included credits are sorted newest first. Each displayed item can contain:

- Title and release year.
- Character name.
- Overview.
- TMDB vote average.
- Poster path.

Malformed entries and credits without a title or date are ignored.

## Display and Navigation

The page renders eight visible credit rows at a time with an animated focus
highlight. Up and Down move one credit, while Left and Right move ten credits
and clamp at the beginning or end of the list.

The focused credit updates the preview with its title, release year, overview,
and poster. Posters use TMDB's `w342` image endpoint:

```text
https://image.tmdb.org/t/p/w342{posterPath}
```

Credits without posters still show their available text. The current page is a
browsing surface only; selecting a TMDB credit does not open or play a matching
Jellyfin item.

Back closes Filmography and restores the underlying person page.

## Loading and Errors

The shared application spinner is shown while filmography is loading. A failed
request hides the spinner and reports the error through the shared application
status message. A successful response clears stale status and renders the
available credits. An empty or fully filtered response leaves the list and
preview hidden.

Deactivating the page stops the task and invalidates its active async lifecycle
so a delayed response cannot update a closed or replaced Filmography page.

## External-Service Boundary

The TMDB API key is sent directly to TMDB as the `api_key` query parameter over
HTTPS. Filmography availability and accuracy therefore depend on:

- The user-provided API key remaining valid.
- Jellyfin supplying a usable TMDB person URL.
- TMDB availability and combined-credit metadata.
- TMDB image availability for returned poster paths.

Starfin does not use TMDB to replace Jellyfin metadata or to resolve a credit
to a playable Jellyfin library item.

## Verification

Verify the feature with people who have movie credits, television credits,
missing posters, malformed credits, and no TMDB identity. Also verify missing
and invalid API keys, an empty TMDB response, request failure, rapid page
closure, focus movement beyond eight items, and focus restoration after Back.

Relevant automated coverage lives in:

- `tests/specs/components/tasks/Video/FilmographyTask.spec.bs`
- `tests/specs/components/pages/Video/Cast/Person.spec.bs`
- `tests/specs/components/pages/Video/Cast/Filmography.spec.bs`
- `tests/specs/components/pages/Video/Cast/Filmography/FilmographyCard.spec.bs`
