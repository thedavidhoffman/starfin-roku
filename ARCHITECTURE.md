# Starfin Roku Architecture

This document is a working map of the application. It describes responsibility
boundaries and runtime relationships; feature-specific implementation details
belong beside the owning component.

## Runtime entry point

`source/main.bs` creates the `roSGScreen`, initializes global resolution, the active theme, and
logging services, creates `MainScene`, and owns application exit and Roku memory
events.

`components/pages/MainScene` is the app shell. Its XML owns authentication,
top-level page hosting, the header, shared acknowledgment dialogs and loading UI, global overlays,
and app-level controllers. Its local helper files divide routing by feature while
keeping the `MainScene` component context.

`DeepLinkController` owns the app-wide deep-link lifecycle. It normalizes launch
and input events, retains the latest request while authentication is unavailable,
serializes correlated resolver work, and publishes destination requests without
holding page references. `MainScene` executes those destinations and reports
readiness or failure back to the controller. This keeps Roku performance beacon
signaling at the app-shell boundary while playback and season pages remain the
owners of their own loading and rendering lifecycles.

## Directory responsibilities

- `components/pages/`: User-facing screens and feature surfaces. A page owns its
  feature-specific loading, response handling, local state, focus, and navigation.
- `components/controls/`: Reusable SceneGraph UI controls. Controls expose narrow
  fields and interface functions and should not own page-specific API behavior.
- `components/controllers/`: Long-lived coordinators used across page changes,
  such as authentication, media actions, playback lifecycle, and theme audio.
- `components/tasks/`: SceneGraph task nodes for API and background work. Tasks
  accept explicit request data and publish correlated response data; they do not
  reach into page or scene state.
- `components/services/`: App-wide service nodes, currently including logging.
- `components/screensavers/`: Screensaver surfaces and lifecycle behavior.
- `source/`: Shared BrighterScript namespaces and application startup. Put reused
  pure logic, formatting, state helpers, API utilities, and stores here.
- `tests/rooibos/`: Rooibos entry point, fixtures, and unit/component specs. The
  specs mirror production ownership.
- `tests/automation/`: Off-device RTA smoke tests, support helpers, and local
  automation environment configuration.

## Component-local helpers versus shared source

Large SceneGraph components may split responsibilities into local helper `.bs`
files imported by the owning component. Those functions share the component's
`m` context and remain lower-camel-case component functions.

Shared helpers under `source/` use BrighterScript namespaces and should generally
be independent of a particular component context. Qualify calls across namespace
boundaries using `Namespace.Member()` syntax. Within the same namespace, prefer
unqualified calls unless explicit qualification is needed to resolve ambiguity.
File-private namespace helpers use the `__` prefix.

Move logic to `source/` when it is reused or is a self-contained calculation.
Keep it local when it coordinates child nodes, focus, observers, or the owning
component's state.

For field callbacks that require initialized references or state, establish those
dependencies before registering observers in script, then explicitly process
current field values. This avoids early XML callbacks and renders values assigned
before registration. Handlers do not rerun `init()` to recover state. Controls
with an explicit consumer-owned render request, such as MediaMetadataRow, wait
for that request rather than rendering placeholder inputs during initialization.
See [List and Grid Item Initialization](.docs/feature/list-item-initialization.md)
for the affected controls and test coverage boundaries.

## Navigation and overlays

`MainScene` routes between major surfaces. Feature pages emit narrow event-like
fields such as selected items, close requests, or overlay requests rather than
delegating their internal task workflow to the scene.

Dynamic pages are hosted under `dynamicPageHost`. Pages are responsible for
activation, deactivation, focus restoration, and clearing stale local state.

Dialogs that must cover the current page and header are requested through
`OverlayHost`. The originating page emits an `overlayRequested` assocarray that
identifies the dialog/content component, open function, close field, source page,
and feature payload. `MainScene` routes the request; the feature handles the
result and restores focus.

Message presentation uses a dedicated top-level OverlayHost above ordinary overlays
and the spinner. AppMessage.Show/Dismiss route through narrow MainScene interfaces.
MainScene owns deferred opening, deduplication, modal focus protection, and return
focus; MessageDialog and MessageContent own frame, layout, acknowledgment, and
scrolling. Dismissal releases retained node references. Successful background work
must not dismiss messages. Home aggregates failures within its current refresh
before presenting them; progress and empty-state labels remain with their owners.
MainScene routes Home hiding through hideHome() and suppresses outgoing refresh
messages during page/session cleanup. Home owns that refresh-level suppression.
Message acknowledgment respects the current confirmation host and blocking spinner
before restoring older focus. MainScene chooses the active layer; the Settings
failure dialog owns its default Keep editing focus through the Dialog focusContent
interface. Message dismissal does not restart save progress or make save decisions.

## Requests, responses, and state

SettingsDialog owns account subtitle configuration loading, serialized
saves on close, and retained pending edits on failure. SettingsContent owns its editor and language
picker. A separate top-level confirmation OverlayHost preserves Settings underneath
a feature-owned failure dialog. MainScene routes correlated requests/results;
SettingsDialog owns Retry/Discard/Keep editing and the canonical close path.
Its component-local AccountSubtitleSession.bs helper contains account session state,
requests, response handling and failure decisions; SettingsDialog.bs retains
dialog setup, local persistence, previews and closure. Both share the same
component context; no separate controller or additional routing layer is involved.
Its response boundary handles correlation and task cleanup, then dispatches to
separate load/save completion handlers. SettingsContent owns captured editor focus
and its restoration, including focus-dependent descriptions. The dialog supplies a
stable language catalog after loading; selection/status updates do not rebuild it.
Closing saves use Spinner.ShowBlocking(2): input is blocked immediately, visuals
are delayed, and existing callers retain immediate visuals by default. AccountSubtitleTask fetches and updates the signed-in Jellyfin account
using explicit session context passed through MainScene and OverlayHost. These
preferences do not enter SettingsStore; local settings still save on dialog close.
Playback continues to use Jellyfin's resolved subtitle default.

- Pass session and feature context explicitly in request assocarrays, including
  values such as `server`, `token`, `userId`, library IDs, and item IDs.
- Task responses should include a success field, correlation identity such as
  `itemId` or query ID, payload data on success, and an error message on failure.
- Use `AsyncLifecycle` when responses can arrive after a page changes. Use
  `LatestRequestLifecycle` when Task work must serialize replaceable requests:
  it assigns request generations, coalesces pending work, and rejects stale
  responses even when two generations target the same item. When a response
  observer needs to start pending work immediately, alternate between a bounded
  pair of Task nodes instead of restarting the node still publishing a response.
- API response data uses Jellyfin's PascalCase field names. Component-owned view
  models may use locally defined lower-camel-case fields.
- Group related component state under a named state object rather than adding
  several unrelated `m.*` variables.

## Theme state and rendering

The theme preference remains in SettingsStore's per-account registry data.
`source/main.bs` creates the observable global string field `theme` with Blue
before creating MainScene. MainScene's `syncTheme` is the runtime writer: settings
fan-out publishes the loaded or committed account theme, while login routing and
application reset restore Blue. Settings selection previews travel through
SettingsContent, SettingsDialog, and OverlayHost events to syncTheme without
changing committed settings. Dismissal restores the current session theme. Components read the global value without registry
access or knowledge of the active session.

`ThemeBackground` owns the app-shell background's solid backing Rectangle and themed gradient
Poster, reading the current theme during initialization and observing subsequent
changes. `source/Theme.bs` owns normalization, background colors, and image paths. MainScene
hosts a single ThemeBackground behind its pages and overlays. Up Next has no
local backdrop and shows this same background after the player is removed. HeaderDropdownMenu
also observes the global theme and applies the Theme.HeaderMenu palette to its
background layers, identity divider/text, and existing menu item buttons. Theme
asset paths are centralized under images/themes/{theme}, with fhd/hd variants
for nine-patch menu and dialog assets. Shared Dialog observes global.theme and
uses Theme.DialogPanelUri to update its frame without replacing content or focus. The existing Theme.Get palette used by other controls
remains unchanged. SquareButton observes the same global field, applying its
Theme.SquareButton palette to fixed tiles, wide-button tints, and active text.
Header observes theme changes and supplies Theme.AccountBadge colors to the
badge; AccountBadge continues to own its renderer-compatible compositing.

## Media flow

Libraries own loading, filtering, paging, and their grid state. Selecting an item
emits the context required to open a detail page. Detail pages own metadata,
watched state, stream selection, local browse state, and playback selections.
Playback is launched using a selection payload containing the item identity,
media context, resume position, selected streams/mode, and any applicable queue.
Progress and watched-state results flow back as narrow events so the originating
surface can update its data.

`MediaOptionsDialog` is shared by movie/episode detail pages and VideoPlayer.
Its content owns an initial snapshot and pending selections; Back publishes one
change-only result through OverlayHost. Pages own applying those selections.
VideoPlayer owns a single combined commit that selects local updates or one
correlated playback restart and restores prior playing/paused state. MainScene
and PlaybackController route the overlay without applying individual options.
MediaOptionsSession calculates display defaults and detail-page stream changes
without side effects. Its context accepts selection intent and an optional resolved
subtitle index separately; playback supplies both and detail pages supply intent. ActivePlayback owns accepted stream indices; subtitle request intent remains separate
from the resolved subtitle index used for same-title recovery. VideoPlaybackInfoTask
owns bounded automatic-subtitle discovery and delivery negotiation; startup
restoration intent stays on the playback request until the first playing state,
including across recovery retries.

`PlaybackController` owns the app-shell lifecycle of the active `VideoPlayer`
node: creation, event wiring, delegated shell commands, restoration snapshot
capture, and teardown. `VideoPlayer` remains the canonical owner of accepted
playback state, Jellyfin playback tasks, queue transitions, and Roku runtime
mechanics. `MainScene` retains page visibility, navigation, focus restoration,
and routing decisions and does not access the player node directly.

Multi-version movies retain a `MovieVersions` context separately from their
selected source metadata. Movie owns the detail-page choice; MediaOptionsContent
owns pending version drafts and correlated MovieTask loads; VideoPlayer owns the
combined restart and accepted selection. JellyfinMovie supplies the shared
metadata request used by MovieTask and direct playback resolution. Playback
requests/restoration retain the complete catalog, while timeline requests and
resume data use the selected version. MainScene remains a router.

Remote Play remains page-owned input handling: browsing pages emit a focused
playback selection, while detail pages reuse their existing Play/Resume builders.
MainScene owns one shared playback return context and player routing for ordinary
video, remote Play, and albums. Launch callers provide an explicit origin before
it is hidden; player closure and next-episode cancellation share restoration.
Pages retain metadata reconciliation and focus ownership. Person retains the
suspended launch's context/snapshot for its temporary detour; new launches replace
the active destination. PlaybackController exposes the owned player restoration
snapshot without owning navigation destinations.
VideoPlaybackInfoTask owns direct-launch item hydration before negotiation;
VideoPlayer retains accepted metadata through its normal recovery lifecycle.
AudioPlayer continues to own ordered album playback and pause/resume behavior.

## Build and test boundaries

`bsconfig.json` builds the production channel. Component-specific pure playback
helpers live directly in `source/video-player-helpers`, using responsibility-named
namespaces. Purity means independence from component `m` state, not necessarily
use by multiple components. Production, Rooibos, and automation builds include
them through the ordinary `source/**/*` rule; their repository and package paths match without
remapping. Their pure unit suites live in
`tests/rooibos/specs/source/video-player-helpers`.

`bsconfig-test.json` builds the Rooibos channel. It remaps test specs into the
package's `source/tests` tree and also includes component scripts so `@SGNode`
tests execute against real SceneGraph nodes.

`bsconfig-automation.json` builds the real Starfin channel with RTA's
OnDeviceComponent included and `enableRta` enabled. The off-device tests under
`tests/automation/` deploy and control that package, reset the sideloaded
development channel registry before the suite, authenticate with its local test
account, inspect the running scene, and write HTML reports and screenshot
evidence under `out/automation-results/`.
The shared manifest disables RTA by default, and only the automation build
overrides that value. Automation components and runtime initialization are not
shipped in the production or Rooibos packages.

Available checks (choose according to the development stage and change scope):

1. `npm run validate` for the production build.
2. `npm run test:build` for test compilation and packaging.
3. `npm test -- --host <roku-host> --password "<developer-password>"` for the
   full runtime suite on a Roku development device.
4. `npm run automation:test` for the RTA device smoke suite and evidence report.

The user owns the development-cycle boundary. Follow the development-cycle
verification gate in AGENTS.md: during an open cycle, implement changes, update
tests, and review code and diffs without running builds, automated validation,
tests, UI automation, device checks, or deployments unless explicitly requested.
Finishing an implementation turn or implementing a plan containing verification
steps does not authorize those checks. Runtime uncertainty does not create an
exception; describe it and defer verification.

When the user declares the cycle complete or explicitly requests comprehensive
verification, run the full device suite for component, observer, focus, field-type,
and Roku runtime behavior changes, plus applicable UI automation. Compilation
alone cannot validate those semantics. Report completed checks and deferred
verification without treating deferred checks as a blocker during development.
Keep credentials out of version control and command examples with real values.

## Generated and local files

`build/`, `out/`, `node_modules/`, local deployment configuration,
`tests/automation/.env.automation`, and logs are not application source. Preserve
unrelated working-tree changes and follow the special handling for user-owned
files documented in `AGENTS.md`.

## Settings presentation and persistence

SettingsDialog owns its fixed dimensions, SettingsContent owns the card width,
and SettingsCard owns its content inset and native radio focus overhang. SettingsCard
derives radio geometry and owns reusable card rendering. SettingsNavigation names
subtitle category, control and page indices. SettingsContent owns controls, focus
and the two-page subtitle editor. Category panel components contain layout only;
SettingsContent creates Libraries initially and retains other panels on first visit.
It owns their references, observers, option content and rendering, plus the complete
edited snapshot independently of which panels exist. SettingsDialog supplies the
account key before the single explicit settings load. Subtitle state and language
catalog fields retain data received before their panel is created.
Local burn-in is an account setting,
while mode/language retain SettingsDialog-owned Jellyfin writes. SettingsStore
ignores the legacy device burn-in value; the settings migration helper removes
that obsolete key during settings loading. Accounts without a saved value use
During transcoding.

Subtitle navigation uses two fixed pages (Jellyfin preferences, then local
burn-in) with a non-focusable chevron/page indicator and a short fade. This
keeps SettingsContent responsible for paging.

SettingsContent owns the media-layout radio cards, edited snapshot, and two-page
navigation independently of subtitle paging. The first page contains paired
Movie/Music and TV Series/TV Episode rows; the second contains Theme music.
SettingsCard owns rendering and radio geometry, preserving explicitly declared
card widths. SettingsStore retains independent account preferences for movies,
TV series, TV episodes, and music, with legacy compatibility on read and cleanup
through the settings migration helper. Detail pages own applying their preferences; MainScene includes
MusicArtist in its committed-settings fan-out.

SettingsContent owns paired badge-style cards in Theme and the original
single-page TV settings layout. MainScene publishes
the per-account count preference through the same preview/commit boundary as
watched style. MediaStatusBadge observes both badge preferences and owns numeric
and watched-check presentation; owning cards retain placement and eligibility.
Library, Home, Search, TVShow and TVSeason own aggregate count refreshes through
local UnwatchedEpisodeCountRefresh children with explicit session data. The
refresher only coordinates correlated Task requests; pages merge returned server
counts into canonical data and existing ContentNodes without changing focus.
See [Watched Indicators and Unwatched Episode Counts](.docs/feature/watched-indicator.md).

## Settings registry migrations

`SettingsStore.Load()` synchronously invokes `SettingsMigration.Migrate()` before
reading account or global settings. The helper checks for obsolete keys across
all existing accounts and performs global cleanup. No version marker is used;
completed migrations perform no writes or flushes. Failures are contained and
retries depend on obsolete data remaining visible in the registry. SettingsStore
retains read-time legacy compatibility. Normal saving owns current
preferences only. Migration never calls Load or Save, avoiding recursive loading
or saving unrelated defaults. No startup task or background registry writer is
introduced. See [Settings Migrations](.docs/feature/settings-migrations.md).
