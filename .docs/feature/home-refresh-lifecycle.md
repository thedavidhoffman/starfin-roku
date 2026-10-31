# Home Refresh Lifecycle

The Home lifecycle RTA coverage includes a controlled HTTP fixture for blocking
refresh failure. It holds both core responses, fails Continue Watching with HTTP
503, and releases Next Up separately to check loading, error presentation, and
usable shelf focus after acknowledgment. Only Home's temporary load request uses
the fixture; cleanup restores that request and closes the server. The Roku must
be able to reach the test runner's local address and ephemeral HTTP port.

Home data loads use a generation and account-session identity so only the
current refresh may update shelves, loading state, or focus. Every full or
playback-row refresh invalidates the prior generation and cancels its owned
Task nodes before creating a fresh bounded set of one-shot tasks.

A return refresh carries unfinished work and sections affected by mutations into
its new generation. It reloads only sections with outstanding requirements,
including affected Recently Added libraries.
Watched changes and video playback progress invalidate all eligible non-music
Recently Added libraries because change events do not identify the owning library.
This also covers items absent from the retained snapshots (including empty shelves)
and episodes grouped into show cards. Jellyfin determines membership on reload;
marking a hidden movie unwatched can therefore bring it back without a full Home refresh.
Completed rows stay rendered. Restarted core requests participate in completion,
while Recently Added retains its existing background-loading behavior. Repeated
refreshes replace the pending work again; superseded responses remain ineligible
to commit.

Each task receives `homeQueryId` and `homeSessionKey` in its private request
snapshot. Response handlers verify the task is still the action's owned node and
that both values match current Home state. Stale success and failure responses
therefore cannot render data, clear the spinner, publish an error, or complete a
newer blocking refresh. The account key is preferred as session identity, with
normalized server and user ID used when no account key is available.

Core task nodes retain their established IDs while the completed refresh is
visible so device automation can inspect their terminal states. They are
detached when superseded. Per-library Latest Media tasks are detached as each
response completes.

Home and Live TV attach dynamically created tasks beneath their owning page and
publish the task through `taskCreated`. MainScene observes that event and adds
the standard authentication-response observer before the task runs. A 401 from
a dynamic Latest Media or Live TV schedule request therefore expires only the
matching active account through the same path as declarative task nodes.

## Focus during refreshes

Background responses reconcile Home shelves by row key. Unchanged shelves and
their content remain attached, retaining native item focus and dialog return
references. Added rows update layout and navigation indices without replacing
unrelated shelves. Changed rows retain the selected item by ID, or the nearest
valid item index when it disappears. If a whole row disappears, Home uses the
nearest remaining shelf, or focuses Home itself when no shelves remain.
Responses never take focus from Settings, the header, another page, or a dialog.
Shelf focus is restored only when Home already owned focus and remains visible.
Initial navigation explicitly focuses Home, so arriving rows still receive focus
when the user stays on Home.

A blocking refresh takes Home focus when it starts, then restores shelf focus on
completion only if Home still owns it. Opening Settings during that refresh leaves
Settings focused when the final response arrives. Explicit navigation back to Home
continues to use `focusHome`.

Home owns refresh requirements, mutation revisions, and account-scoped raw section
items. MainScene forwards navigation and normalized changes; it no longer owns a
playback-row dirty flag. Successful watched, favorite, and playback changes update
every retained occurrence, including Recently Added. Next Up is a derived view of
its unfiltered section and Continue Watching, rather than a separately writable cache.

Each section request captures the current mutation revision. Completion acknowledges
only that revision, so changes made after launch remain pending. Older snapshots
receive newer local field changes before rendering. Series/season mutations refresh
server-derived video shelf data and counts rather than inventing aggregate totals.

Activation loads initial content or refreshes pending sections. Departure explicitly
marks Home inactive and suppresses errors; late responses may update retained data
but cannot reopen Home or focus it. Account replacement clears account-specific state
and invalidates all owned requests. Pending work is carried into superseding refreshes.
Failed sections retain their previous content and remain pending for the next activation;
they do not spin in an automatic retry loop. Newer mutations can trigger follow-up work.

One completion path releases loading, establishes visibility and valid shelf focus,
and then publishes aggregated errors. This ensures acknowledgment returns to a usable
card. Blocking refreshes retain loading until core work settles; nonblocking initial
loads release it once usable rows appear. Readiness resets on each core load, and
MainScene ignores false readiness notifications. Immediate layout corrections and
full clears stop obsolete shelf animations.

## Home item selection

OK on an On Now program plays its `ChannelId` through the existing live-channel
player and returns to Home. Programs without a channel ID do not launch a player.
OK on Continue Listening resumes that individual audio item through AudioPlayer;
it does not load an album queue. Music videos launch the existing video player
with item-detail hydration. Ordinary library and album selections retain their
existing routes. Opening a photo from Home uses the same hide/suppress lifecycle
as other departures, preventing late Home error messages over the viewer.

Each refresh tracks whether it owns Home's loading spinner. A nonblocking refresh
releases it on usable rows or empty completion; a blocking refresh releases it only
when its required core work settles. Leaving
Home relinquishes it through the existing navigation suppression path, so late
core or Recently Added responses cannot hide another page's spinner. A new
blocking playback refresh acquires its own loading state.

The direct Settings automation helper waits for initial Home readiness before
opening its category, matching the system-menu helper. Focus assertions remain in
place, and component regression tests cover responses arriving after Settings opens.

## Live TV permission and denied access

AuthController derives `permissions.canAccessLiveTv` from the authenticated user's
`Policy.EnableLiveTvAccess`. Only boolean true grants access; missing policy or
permission defaults to false. Permissions remain in memory and are rebuilt by
sign-in, saved-session authorization, Quick Connect, and account switching. They
are not persisted in the registry and require no additional API request.

MainScene passes permissions through the session load request. Home skips its
On Now task when access is unavailable and marks that core task complete so the
normal readiness, spinner, and focus lifecycle can finish.

A current On Now HTTP 403 is logged and the row omitted without setting or
clearing the shared status message. This handles permission changes after login.
Only action `liveTvOnNow` with numeric status 403 receives this treatment. Other
errors remain visible, and the existing 401 authentication-expiration route is unchanged.
Stale task responses are rejected before permission-error handling.

## Recently Added exclusions and error messages

AuthController retains User.Configuration.LatestItemsExcludes in the runtime
session's homePreferences, defaulting to an empty list. MainScene forwards these
preferences to Home. They refresh on authentication and saved-session validation,
including account switching; they are not stored in the registry. Changes made
on another client take effect after the next session validation or sign-in.

Home excludes matching library IDs before scheduling Recently Added tasks.
This does not remove libraries from My Media or change library access.

Home failures identify the affected section, including the library name for
Recently Added. Home uses RequestFailure.GetMessage with the HTTP client's structured failureKind;
it does not classify failures using technical message text or HTTP codes.
Unknown or missing identifiers receive the unexpected-response explanation. HTTP logs retain technical details. Authentication expiration and the
On Now 403 exception remain unchanged. Empty-Home behavior is unchanged.

## Aggregated acknowledgments

Each refresh owns a message list. Accepted failures are collected, preserving the
On Now 403 omission, and published once through AppMessage after core and current
Recently Added requests finish. Existing ready/spinner timing remains intact. A
new refresh discards prior collected messages; stale responses cannot contribute.
Successful responses never dismiss a visible acknowledgment.


MainScene's hideHome() and page/session cleanup call suppressRefreshMessages().
This clears the current refresh's collected failures and suppresses subsequent
failure presentation, including delayed Recently Added failures, without canceling
row loading. Starting another refresh resets suppression. Returning to the same
refresh does not display its discarded errors. Opening an overlay keeps Home's
refresh eligible to present messages.

## Episode artwork preference

Settings > TV includes "TV artwork in Next Up and Continue Watching", stored
per account as
`home-episode-images`: `series`, `episode-with-logo`, or `episode-without-logo`. The options
are Series artwork, Episode thumbnail with logo, and Episode thumbnail without
logo, respectively. The default is `series` for missing or unrecognized values.
Legacy values are not migrated or mapped. Settings retains its existing save-on-close
behavior (including Back); there is no separate Cancel action.

Both episode modes prefer the episode's own Primary still. Missing stills use the existing series thumbnail/backdrop/poster
fallback chain. `series` preserves that previous image-selection behavior. Movies,
other rows, and card geometry are unchanged. `episode-without-logo` displays the
still without the logo or gradient. Switching between episode modes updates
overlay fields even though the still URL is unchanged; no data reload is needed.

With `episode-with-logo`, when either row selects an episode's own Primary still,
its thumbnail card can overlay the inherited show logo using `ParentLogoItemId` and `ParentLogoImageTag`.
Both row requests include `Logo` in `EnableImageTypes`; no additional series
lookup is needed. Missing logo metadata leaves the still unadorned. The PNG logo
fits within 40% of the artwork width and 25% of its height, with a 12-pixel left
inset and a 9-pixel gap above a visible progress bar. Without a progress bar
(including Next Up), the logo sits 12 pixels above the artwork's bottom edge.
Placement follows progress visibility when cards are reused. Logos retain their aspect ratio.
Series artwork, movies, and other rows never receive this overlay. Artwork and
`logoOverlayUrl` update together when the setting changes, and recycled thumbnail
cards clear the logo when the next content has no overlay URL.

A soft black gradient behind the logo improves contrast on light episode stills.
It reaches 68% opacity at the bottom-left, fades upward and toward the right,
and scales with the artwork inside its rounded mask. It is drawn below the logo
and progress bar and appears only after the current logo loads successfully.
Loading, failed, cleared, or replaced logos leave the gradient hidden. Logo placement
and sizing are unchanged; the gradient follows the title-logo option. The texture is
reproducible with `node scripts/generate-logo-gradient.mjs`.

The top-left experiment was reverted; placement is bottom-left with `x = 12`.
With a visible progress bar, `y = progressBar.translation[1] - logo.height - 9`;
otherwise, `y = poster.height - logo.height - 12`. At the standard 441 by 249
artwork size, the logo box is 176 by 62, positioned at `[12, 160]` with progress
or `[12, 175]` without it. The size limits and `scaleToFit` mode are unchanged.

MainScene distributes committed settings to HomePage through its `settings`
field. Home updates only the existing image fields in the affected ContentNodes,
retaining shelves, selection, scroll position, metadata, and progress. No data
requests are issued. Subsequent responses use the latest preference, while the
existing generation/session checks continue rejecting stale responses.

System Info includes this preference in each account's registry section. Account
settings are listed from `SettingsStore.AccountKeys()` so new preferences are
included automatically. Device-wide streaming and subtitle burn-in settings
appear once under Global Application Registry. Coverage checks every defined
setting appears exactly once in the correct scope, including effective defaults.

Standalone audiobook playback preserves the Jellyfin `AudioBook` type through Home
selection, playback reporting, and Continue Listening reconciliation. Jellyfin decides
resume eligibility: ordinary music `Audio` tracks do not retain bookmarks on 10.11.11.
Audiobook bookmarks must fall within the server-configured resume thresholds.
