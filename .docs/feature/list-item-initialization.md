# List and Grid Item Initialization

Content and focus fields may already hold values when a list item's initialization
finishes. Item rendering must not depend on receiving another field change to
display those values.

The following components register their content observers in `init()` after
initializing their node references, styling, and local state, then immediately
process the current content:

- VideoMediaCard
- TVSeasonCard and TVEpisodeCard
- MusicAlbumCard and HomeMusicAlbumCard (which share the same script)
- ArtistAlbumRowItem and AudioTrackListItem
- CastItem and AccountPickerItem
- ServerDiscoveryItem

TVEpisodeCard, AudioTrackListItem, and ServerDiscoveryItem also register their
focus observers after initialization and apply the current focus fields. Season
watched-state and server-list focus subscriptions remain owned by the existing
content handlers, including their existing replacement and removal handling.

These fields no longer declare XML `onChange` callbacks in these components.
Assignments before observer registration retain their latest value on the node;
the explicit initial render consumes it. Later assignments use the registered
observers normally. There are no retries, swallowed exceptions, or changes to
content ownership or presentation choices.

This follows the mitigation for the suspected early callback behind the
[VideoMediaCard crash](video-media-cards.md). That native event ordering has not
been reproduced. Regression tests create fresh production component instances
through `CreateObject` and exercise content, focus, replacement content, watched
state, and list focus through existing fields and observable rendering. They do not
call `init()` directly, remove observers, or invalidate production state. They
verify behavior after construction, not assignments before native initialization
or Roku's native creation timing.

## Shared control initialization

SettingsCard, ProgressBar, and ThemeBackground use the same
ordering for their rendering and sizing fields: establish required references
and local state, register observers in script, then apply the current field
values. Their rendering and sizing fields no longer use XML `onChange` callbacks.
Field types, defaults, aliases, interface functions, geometry, and theme behavior
are preserved. ThemeBackground retains its existing global theme observer.

Shared-control tests create fresh instances and assert initial rendering and
subsequent field changes without directly invoking `init()`. Coverage includes
card text and dimensions, progress clamping,
background dimensions, and theme changes. List-item tests also use fresh
production instances, avoiding the Rooibos generated initializer and shared suite
state that made the earlier direct-`init()` tests unsafe.

MediaMetadataRow initializes references without rendering or field observers.
The consumer supplies its first render. Its callers pass a complete
`MediaMetadata` through
`callFunc("render", input)` to update children and render once. The row retains no
input fields or content snapshot. This avoids both early field callbacks and
repeated rendering for a multi-field metadata update. Its tests cover
deferred rendering, complete replacement, clearing metadata, width changes, and
configured spacing. See
[Detail Metadata Ratings](detail-metadata-ratings.md).
