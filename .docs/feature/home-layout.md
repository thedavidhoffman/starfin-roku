# Jellyfin Home layout

Starfin reads the signed-in user's Jellyfin Home section visibility and order.
HomePreferencesTask requests GET /DisplayPreferences/usersettings with userId
and client=emby. It reads PascalCase CustomPrefs; the dictionary keys
homesection0 through homesection9 retain Jellyfin's wire spelling. This feature
does not write server preferences or add registry settings.

## Resolution

HomeLayout resolves slots in numeric order. Missing or empty values use Jellyfin
defaults: smalllibrarytiles, resume, resumeaudio, resumebook, livetv, nextup,
latestmedia, then three none slots. Explicit none omits a slot. Unknown sections,
Active Recordings and Continue Reading are skipped without requests or gaps.
Repeated supported sections use their first position.

Small library tiles, library buttons and legacy folders use Starfin's My Media
presentation. Resume, resumeaudio, nextup and livetv map to Continue Watching,
Continue Listening, Next Up and On Now. Latest Media expands into eligible
per-library Recently Added shelves in the library response order. Existing
LatestItemsExcludes remain applied before scheduling those library requests.
My Media can be hidden. The library lookup still runs if Recently Added needs it.
Live TV permission gating and omission of empty shelves remain unchanged.

## Combined watching

The saved Combine Continue Watching and Next Up setting is effective only when
both sections are enabled. The combined shelf uses the earlier slot and retains
the Continue Watching row identity. The later slot disappears without a gap.
With only one enabled, its normal title and configured position are used; with
neither enabled, neither is shown. The saved Combine setting is never rewritten.
Sorting history is requested only when effectively combining. Hidden Continue
Watching data does not filter the standalone Next Up row.

## Ownership and lifecycle

HomePage owns a layout state object containing session preferences, resolved
layout, loading state and ordered latest-library row keys. HomeLayout is pure;
HomePreferencesTask owns HTTP. MainScene remains a router.

Initial loading and full Home refresh fetch preferences before content.
Playback-only refresh reuses the resolved layout. Changes in Jellyfin apply on
the next full Home refresh or session/app reload. Session replacement clears the
remembered layout. There is no polling or cross-account registry cache.

The preference request times out after five seconds. Non-authentication failure
or malformed payload logs a fallback and uses the previous valid session layout,
or defaults if absent. Authentication failure follows existing expiration routing.
Task identity, query generation and session correlation reject stale responses.

One resolved layout gates required requests, dirty playback/audio requests,
library dependencies and row order. Hidden sections do not block readiness or
produce content errors. All-hidden layouts stop the spinner and remain navigable
to the header with Up. Initial focus uses the first populated configured row;
existing identity-based focus restoration applies during subsequent projection.

## Coverage

HomeLayout specs cover normalization, aliases, duplicates, unsupported slots,
empty layouts and combined ordering. HomePage specs cover preference gating,
request suppression, audio settlement, library dependencies, combining, failures,
session replacement and stale tasks. HomePreferencesTask specs cover validation,
payload and failure propagation. Home automation checks real HTTP request
selection and visible shelf order through the fixture server.

The test-build-only home-layout-cases plugin expands the parameter marker in
HomeLayout.spec.bs before Rooibos discovers tests. It enumerates all 1,957 ordered
subsets of the six supported section types, each with Combine off and on, yielding
3,914 independent parameterized cases. They are registered as generated source
files under build/rooibos-fixtures, in batches of at most 128 cases per suite,
to stay within BrighterScript transpiler metadata limits. Expected order comes from a test-only
remove-later-slot oracle, not the production resolver. Assertions include input
slots and Combine state, and compare order, original sections, enabled sources
and effective combining. Generated source stays in the normal build/out pipeline.

The component matrix separately checks scheduled tasks and rendered rows for
watching combinations, each isolated section, each excluded section across
playback/audio reconciliation, and multi-library expansion with exclusions.
The dedicated Home layout automation suite uses populated HTTP fixtures to check
both watching orders, the row-three/row-five example, all visibility/Combine
combinations, single-section dependencies, merge/split selection, reload focus,
playback request suppression and empty-Home header navigation. Settings changes
in these automation cases use the committed Home settings field; existing Settings
component coverage exercises editor selection and navigation.

## Targeted verification ? 2026-11-13

The enum was renamed to SectionType to avoid BrighterScript's reserved Type
builtin. The task suite has a distinct component name, and exhaustive cases are
split into bounded generated files to avoid compiler metadata limits.

Targeted Rooibos runs compiled and ran on the development Roku. All 3,914
permutation cases passed. Across the selected suites there were five failures:
Home playback focus restoration, stale history request replacement, resume-tick
integer type comparison, TV settings control layout, and TV artwork Down
navigation. The first run stopped after Home because Rooibos defaults to fail-fast;
a second run covered the remaining suites. The runs reported 4,149/4,152 and
4,116/4,118 passing respectively (the permutation cases were repeated).

Targeted device automation reported 19 passing and one failing: Up navigation
from all-hidden Home timed out waiting for header focus. Ordering, supported
section inclusion, combining and content-request checks passed. The failures
were subsequently traced to test setup, stale expectations and an unsupported
automation focus query, and repaired without changing production code.
See out/home-layout-rooibos.log, out/home-layout-rooibos-remaining.log and
out/automation-results/2026-11-13T23-08-10-789Z/report.html.

The repair run passed all HomePage tests. Its combined HomePage/Settings run
reported 412/413 passing; the remaining Settings boundary assertion was then
corrected and the complete SettingsContent suite passed 184/184. The repairs
simulate playback taking focus, settle initial requests before expecting history
replacement, compare resume ticks as LongInteger, and match the current TV/Home
control layout and Home boundary key handling. See out/home-test-fixes-rooibos.log
and out/settings-test-fixes-rooibos.log.

The empty-Home automation case passed on rerun using RTA's dedicated
isInFocusChain API. See
out/automation-results/2026-11-13T23-46-10-349Z/report.html.
Previously passing permutation and automation cases were not rerun for these
test-only repairs. No production defect was identified during this repair pass.

This was targeted verification, not a full development-cycle verification.

