# Episode Detail Browsing

TV episode detail pages in both full-screen and cinematic layouts expose previous and next
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
and focus ownership. The primary episode success or failure ends the shared spinner, while
stale responses leave it running for the pending request. Deactivation cancels
detail loading, deactivates Cast and previous/next controls, clears the spinner,
and releases page focus.

Episode detail requests carry their existing series identity, including whether
series image metadata has been loaded. Matching series context with a name and
known image metadata is reused; missing, partial, or mismatched context triggers
a series lookup. An empty logo URL can represent a confirmed absence and does
not itself require another lookup. Successful series fetches retain that state
through episode navigation and playback refreshes. The episode metadata and
playback queue loading rules are unchanged.

The task publishes `tvEpisodePrimary` immediately after episode metadata arrives.
The page renders details, cast, and media summary and dismisses the spinner at
that point. A later `tvEpisodeSeries` response fills in missing series artwork.
The terminal `tvEpisodeDetails` response supplies the optional navigation queue
and releases the active request so pending work can start on the alternate task.
Every stage is checked against both active and latest request IDs and the current
item. Duplicate primary stages do not reapply metadata. Supplemental updates
preserve focus and selected streams. Failed optional series or queue requests
leave the loaded episode usable. Series and queue HTTP requests remain sequential;
this change removes their latency from the initial usable display.

Supplemental series data is committed once per request and updates only artwork
and the playback selection's series identity. Queue completion updates only queue
context; it preserves the current selection's item, resume position, and selected
streams and copies the current item's state into its queue entry. It never rebuilds
the selection from the original navigation request. This keeps newer playback
progress and watched changes authoritative while optional requests finish.
`SeriesIdentity` owns the single artwork-metadata completeness rule. An explicitly
loaded response records known absence even if the server omits `ImageTags`.
