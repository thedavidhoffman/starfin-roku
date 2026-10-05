# Settings Migrations

`SettingsStore.Load()` invokes `SettingsMigration.Migrate()` before reading account
or global settings, including global-only loads during startup. The helper runs
synchronously without a startup Task or background registry writer. Normal
saving persists current preferences; migration owns obsolete-key cleanup.

## Completion and repeated loads

There is no migration version or completion marker. Each migration checks for
its obsolete data and does nothing when that data is absent. Every settings load
enumerates existing account sections, but completed migrations perform no writes
or flushes. Fresh installs have no obsolete data and write no migration keys or
account defaults. Any marker left by the earlier experimental implementation is
ignored.

Future migrations must be safe to repeat, preserve existing destination values,
and detect whether work is needed from their source data.

## Media shell preferences

The runner visits every existing `STARFIN_ACCOUNT_` registry section, including
inactive accounts and sections without valid authentication data. Unrelated
sections, credentials, and other account preferences are preserved.

When `media-shell-background` exists, migration fills only absent
`movie-shell-layout`, `tv-series-shell-layout`, `tv-episode-shell-layout`, and
`music-shell-layout` keys using the existing compatibility conversion. Present
new keys are preserved exactly, even if empty or unsupported; settings reads
continue normalizing their effective values.

| Legacy value | Movie | TV Series | TV Episode | Music |
| --- | --- | --- | --- | --- |
| Full backdrop | Full backdrop | Corner backdrop | Full backdrop | Full backdrop |
| Corner backdrop | Corner backdrop | Corner backdrop | Corner backdrop | Corner backdrop |
| Cinematic | Cinematic | Corner backdrop | Cinematic | Full backdrop |
| Poster | Full backdrop | Poster | Full backdrop | Full backdrop |
| Empty or invalid | Full backdrop | Corner backdrop | Full backdrop | Full backdrop |

Replacement values are flushed before the legacy key is deleted and flushed.
Attempts with legacy data flush replacements even when all destination keys
exist, because an earlier failed attempt may have left them only in the cache.
The helper also deletes and flushes the obsolete device-level
`subtitle-burn-in-mode` key when present, without copying it to accounts.

## Failure handling

Write, delete, and flush results are checked. An account failure does not prevent
other accounts from being attempted. Migration exceptions are caught so settings
loading can continue, with existing legacy compatibility as the fallback. Logs
contain operation status and exception error numbers, without registry values or
credentials.

Every invocation uses the shared `Logger` to emit one timestamped summary
prefixed with `[SettingsMigration]`. Logs are also collected by the global
LogService when available; exception diagnostics use `Logger.error`:

- `Complete: no obsolete settings found.` when no migration work is needed.
- `Complete: migrated N accounts.` after account migrations succeed, adding
  `; removed obsolete global setting` before the period when global cleanup
  also succeeds. Global-only cleanup reports zero migrated accounts.
- `Incomplete: settings loading will continue.` on any failure, including
  unavailable section enumeration and caught exceptions.

An account is counted only when its legacy layout key existed and migration,
including cleanup flushing, succeeded. Exception diagnostics retain their error
numbers. No starting message, account identifiers, or preference values are logged.

Retries are best effort: the next load attempts any obsolete data still visible
in the registry. There is no cache rollback. If a cleanup flush fails after a
successful deletion, the legacy key may be absent from the current cache but
remain in persistent storage. Its replacements have already been persisted,
so current loads remain safe and a later restart can retry cleanup from the
persisted legacy data. No blocking dialog is displayed.

## Coverage

SettingsMigration tests cover repeated execution, all-account processing,
exception containment, legacy conversion, partial migration, preservation,
no-op sections, read/write/delete/flush exceptions, invalid reads, write and
cleanup failures, flush ordering, and retries after failed writes or restart.
The test registry double separates cached and persisted values.
SettingsStore tests cover load-time cleanup, global-only loads, normal saving
without cleanup, and legacy fallback on failure. Registry-backed settings tests
snapshot all existing sections and their fixture sections before modifications,
then restore them afterward. SettingsContent and SystemInformationContent tests
stub migration so ordinary component settings reads cannot migrate other accounts.
The full Rooibos suite passed on the configured development device: 4,141 tests,
with no failures, crashes, or ignored tests.
