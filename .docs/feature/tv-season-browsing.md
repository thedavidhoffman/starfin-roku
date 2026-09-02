# TV Season Browsing

TV season pages expose previous and next controls that update the existing page
while preserving focus on season navigation.

Season loading uses the shared `LatestRequestLifecycle` helper. The page keeps
one active `TVSeasonTask` request and replaces a single pending request whenever
the user navigates again while loading. Every request receives a monotonically
increasing `requestId`, which the task echoes on success and failure. Only the
latest generation may commit season and episode state.

The page alternates between two `TVSeasonTask` nodes. When an active response is
stale, the newest pending request starts on the idle node instead of attempting
to restart the Task that is still publishing its response. Intermediate season
selections are coalesced so rapid navigation settles on the final selection.

The task publishes primary season and episode data as soon as it is available,
then performs any optional series metadata or season-list work. A correlated
`tvSeasonComplete` response is published last. Primary data may paint without
waiting for optional calls, while only the terminal response releases the Task
lifecycle and starts pending work on the alternate node.

Each selection immediately renders its cached season label and previous/next
availability while clearing the prior season's episode cards. The shared spinner
uses its normal display delay, which restarts as navigation continues. This lets
quick traversal show season identity without flashing loading UI. If loading
outlasts the delay, the spinner remains active across stale work and is hidden
only after the current request succeeds or fails. Deactivation cancels both
tasks, clears pending lifecycle state, and hides the spinner.

Optional series metadata and season-list responses retain season-ID correlation.
They update the page only while their originating season remains current and
never clear the optimistically rendered season label.
