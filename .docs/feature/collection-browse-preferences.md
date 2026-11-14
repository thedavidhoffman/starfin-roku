# Collection browse preferences

Individual collection contents remember Browse By and sort direction independently
for each saved account and collection ID. Supported options remain Title, Release
Date, Date Added, and Favorites, each ascending or descending. Collection contents
do not gain genre, decade, watched-status, or letter filters.

## Default and persistence

An untouched collection opens with Title, ascending and creates no saved entry.
A user selection of a non-default preference saves through LibraryViewStateStore.
Returning to Title, ascending removes that collection's record.
Other library types retain their existing persistence behavior; playlists remain
excluded. No automatic pruning or bulk initialization is performed.

The existing account section and `library-view-state-<collectionId>` key are used.
The value retains the existing seven-field state format, including display metadata.
System Information enumerates matching registry keys directly, sorted by library ID.
The former `library-view-state-index` is ignored during reads and deleted on the
account's next save, including an unchanged save.
Cleanup shares a single flush with any preference change and leaves other records
untouched.

VideoLibrary owns supported-choice normalization, restoring the selection before
its first item request and synchronizing Browse By and Sort controls. Unsupported
saved collection choices fall back to Title, ascending without rewriting storage.
Malformed records use normal request defaults. Collection navigation uses each
collection's own ID; returning to a parent restores its independent preference.

## Store writes

`LibraryViewStateStore.Save` updates the requested preference and removes any
obsolete index. `Remove` deletes only the requested preference. Unchanged saves
with no index to clean up and removals of absent records skip writes and flushes. Reads remain read-only. Registry
availability is assumed: there are no failure return values, rollback, retry,
logging, or acknowledgment messages. If persistence fails, browsing continues
with the current selection, which may not be remembered next time.

## Coverage and verification

The registry-backed store suite covers round trips, direct enumeration, account
isolation, removal, stale-index independence and cleanup, and malformed-record exclusion.
VideoLibrary coverage includes each supported non-default option/direction,
default removal, independent parent/child request restoration, unsupported and
malformed states, initial item requests, and control synchronization.
Existing collection capability tests and library/playlist regression coverage remain.
The parent/child request test does not exercise MainScene's nested navigation;
its preexisting single-parent navigation limitation is a separate issue.

Automated validation, builds, the full Rooibos suite, device navigation/app-restart
verification, and storage measurements are deferred until explicitly authorized.
Device verification should measure 60 and 120 non-default collection records while
preserving and restoring the original registry, then exercise reopen/relaunch,
account switching, and nested collection Back navigation. Synthetic compression
estimates are not a substitute for these device measurements.
