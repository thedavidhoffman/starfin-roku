# Combined Continue Watching and Next Up

Settings > Home offers **Combine Continue Watching and Next Up**, Off by default.
The preference is account-specific (`combine-continue-watching-next-up`). Home also
contains the existing episode artwork control; its `home-episode-images` key and
saved value are unchanged. Both changes apply through the usual settings save flow.

When enabled and both sections are enabled in Jellyfin Home settings, the Continue Watching shelf becomes **Continue Watching & Next Up**
and the separate Next Up shelf disappears. It takes the earlier configured slot.
When only one is enabled, that section keeps its normal title and position; when
neither is enabled, neither appears. The saved Combine preference is retained.
Continue Listening remains separate. See [Jellyfin Home Layout](home-layout.md).
The combined shelf reuses HomeShelf and its video cards, artwork, progress,
metadata, selection and remote Play behavior.

The combine settings card is 248px tall, with its 36px description area at y=194.
The artwork card starts at y=264, preserving a 16px gap between cards.

## Ordering

HomeWatching is a pure source helper. It excludes Next Up items whose item ID or
series ID is already represented by Continue Watching, then orders the remaining
items by descending viewing recency. Resumable items use their own LastPlayedDate.
Next Up uses its own date when present, otherwise its series' newest played episode
date. Equal dates retain source order, with Continue Watching first. Missing dates
sort last. Source arrays and API objects are never modified by the helper.

RecentPlayedEpisodesTask requests the latest 100 played episodes, descending by
DatePlayed, with user data enabled and images disabled. Jellyfin supplies episode
SeriesId directly; it is not requested as an ItemFields value. The bounded lookup
matches Moonfin's history window: series absent from those 100 episodes may have
no inferred date. No combined-row cap is added to the existing source limits.

## Ownership and refresh

HomePage retains separate canonical source datasets and current-session history.
One projection path renders separate or combined shelves. In separate mode, a
Next Up response replaces only Next Up; a Continue Watching response also updates
Next Up filtering. Mode changes update both presentations, while history changes
only affect the combined presentation. Unaffected shelf content is retained.
History uses Home's
existing task ownership, query/session correlation and revision tracking; it is
requested only when combining is effective for the resolved Jellyfin layout. Video progress/watched changes refresh history
alongside both video sources. Older requests cannot acknowledge newer changes.

Enabling combines retained data immediately and requests history when both sections
are enabled in the resolved Jellyfin layout. Disabling cancels
history work and removes its pending/required bookkeeping. A session change clears
history. History failures retain current-session history if available, otherwise
use item dates, and join Home's normal aggregated failure message. Source failures
retain existing Home behavior. An empty combined shelf is omitted.

HomeFocus is a component-local helper for capture, resolution and restoration.
HomePage has one pending return target shared by playback return and shelf
reconciliation; the playback-overlay open flag is separate. A currently focused
shelf is authoritative, including when a dialog restores a native control directly.
An older pending target cannot override that live selection on a later response.
While Home lacks shelf focus, reconciliation retains the pending identity and
resolves it against the current rows, including a merge or split. Restoration
consumes the target only after focusing a shelf or the empty Home page. Missing
items use native nearest-item selection and missing rows use the nearest shelf.
Background responses never take focus from another surface. Initial loading keeps
the existing startup focus choice.

## Coverage and verification

Helper specs cover recency, series inference, duplicates, ties, missing dates and
input immutability. Component specs cover settings persistence/navigation, source
arrival orders, mode changes, focus, history failures, session changes, stale work
and playback-driven refresh. Task specs cover request parameters and responses.
Existing Home playback, artwork and progress coverage remains applicable because
the combined shelf retains the Continue Watching identity and renderer.

Builds, automated validation, runtime tests and UI verification remain deferred
until the user authorizes the development-cycle verification gate. The expanded
category list and cross-shelf focus restoration require device verification.
