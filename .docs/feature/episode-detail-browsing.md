# Episode Detail Browsing

TV episode detail pages in the cinematic layout expose previous and next
controls when the page has a series-scoped playback queue. Navigation replaces
the existing page request while preserving the queue, selected index, series,
and season context.

Episode metadata loading uses the shared `LatestRequestLifecycle` helper. The
page owns one active `TVEpisodeDetailsTask` request and one replaceable pending
request. Rapid navigation coalesces pending work to the newest episode. Every
request receives a monotonically increasing `requestId`, which the task echoes
on success and failure. Only the latest generation may commit page state;
otherwise the page starts the newest pending request without rendering stale
data.

The page alternates between two `TVEpisodeDetailsTask` nodes. Pending work starts
on the idle node rather than restarting the Task that is still completing its
response rendezvous.

Playback-state refreshes use the same serialized request path so they cannot
compete with adjacent-episode navigation for the task's execution state.

Episode and movie details share loading completion, app-status error handling,
and focus ownership. Current success or failure ends the shared spinner, while
stale responses leave it running for the pending request. Deactivation cancels
detail loading, deactivates Cast and previous/next controls, clears the spinner,
and releases page focus.
