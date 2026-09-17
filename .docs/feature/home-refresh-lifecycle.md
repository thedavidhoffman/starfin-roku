# Home Refresh Lifecycle

Home data loads use a generation and account-session identity so only the
current refresh may update shelves, loading state, or focus. Every full or
playback-row refresh invalidates the prior generation and cancels its owned
Task nodes before creating a fresh bounded set of one-shot tasks.

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

Settings > TV includes "Use Episode Images in 'Next Up' and 'Continue Watching'
Sections", stored per account as `home-episode-images` with `on`/`off` values.
The default is Off for new and existing accounts without a saved value. No
registry migration is needed. Settings retains its existing save-on-close
behavior (including Back); there is no separate Cancel action.

When enabled, episode cards in these two Home rows prefer the episode's own
Primary still. Missing stills use the existing series thumbnail/backdrop/poster
fallback chain. Off preserves that previous image-selection behavior. Movies,
other rows, and card geometry are unchanged.

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
