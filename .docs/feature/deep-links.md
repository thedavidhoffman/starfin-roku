# Deep Links and Roku Performance Beacons

## Supported requests

Starfin accepts Roku launch arguments and runtime `roInput` events containing a
`contentId` and `mediaType`. Media type and input keys are normalized without
changing content identifiers. Supported media types are `movie`, `episode`,
`series`, and `season`.

- Movies resolve only Jellyfin `Movie` items and open playback.
- Episodes, series, and season requests resolve through Jellyfin `Episode`
  items. Episode playback receives a cross-season series queue.
- Series requests resume the latest partially watched episode when available,
  otherwise they use Jellyfin Next Up, and build a queue for the selected season.
- Season requests open the owning season and focus the requested episode.

Completed and unwatched items start at zero. Partially watched items retain the
exact Jellyfin playback-position ticks; deep links never display a resume prompt.

## Ownership and lifecycle

`DeepLinkController` is the single owner of normalized input, authentication
deferral, request supersession, resolver correlation, destination identity, and
cancellation. A bounded pair of `DeepLinkResolverTask` children performs API
work with explicit session context. The controller has no page, player, login,
status-label, or `MainScene` references.

Only the latest submitted request can publish a destination. A request received
without a valid session is retained and resumed when authentication succeeds.
Session expiry during resolution follows the same path. Explicit logout, reset,
or an actual account switch cancels the retained work.

The controller publishes one of three destination contracts:

- `playback`: complete playback selection, resume ticks, and optional queue.
- `season`: series and season context plus `initialFocusEpisodeId`.
- `homeFallback`: a bounded failure message for the shared app status.

`MainScene` routes the contract to the owning surface. Playback is ready only
when Roku reports `playing`; a season is ready after its episodes render and the
requested episode is focused; Home is ready after its core refresh completes.
Destination failures and pre-readiness user cancellation are reported to the
controller and converge on Home, allowing a cold launch to complete normally.

## Roku performance beacons

`MainScene` is the only owner of Roku `signalBeacon` calls. Dialog beacons wrap
the pre-Home authentication flow, including saved-account and Quick Connect
paths. `AppLaunchComplete` is emitted exactly once after the final cold-launch
destination becomes ready: Home for a normal or failed launch, playback for
movie/episode/series requests, or the focused season for season requests.
Runtime input events do not emit another launch-complete beacon.

## Certification fixtures

The server-specific certification IDs are configured locally through
`DEEP_LINK_CASES` in `tests/automation/.env.automation`; the checked-in example
documents its `movieId`, `episodeId`, and `invalidId` contract. The same Episode
ID intentionally drives the episode, series, and season cases. This keeps
private Jellyfin catalog identifiers out of source control while allowing the
RTA suite to exercise all four cold-launch and runtime-input paths.
