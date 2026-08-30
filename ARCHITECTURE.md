# Starfin Roku Architecture

This document is a working map of the application. It describes responsibility
boundaries and runtime relationships; feature-specific implementation details
belong beside the owning component.

## Runtime entry point

`source/main.bs` creates the `roSGScreen`, initializes global resolution and
logging services, creates `MainScene`, and owns application exit and Roku memory
events.

`components/pages/MainScene` is the app shell. Its XML owns authentication,
top-level page hosting, the header, shared status and loading UI, global overlays,
and app-level controllers. Its local helper files divide routing by feature while
keeping the `MainScene` component context.

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
- `tests/specs/`: Rooibos unit and component tests, organized to mirror production
  ownership.

## Component-local helpers versus shared source

Large SceneGraph components may split responsibilities into local helper `.bs`
files imported by the owning component. Those functions share the component's
`m` context and remain lower-camel-case component functions.

Shared helpers under `source/` use BrighterScript namespaces and should generally
be independent of a particular component context. Public calls use
`Namespace.Member()` syntax. File-private namespace helpers use the `__` prefix.

Move logic to `source/` when it is reused or is a self-contained calculation.
Keep it local when it coordinates child nodes, focus, observers, or the owning
component's state.

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

## Requests, responses, and state

- Pass session and feature context explicitly in request assocarrays, including
  values such as `server`, `token`, `userId`, library IDs, and item IDs.
- Task responses should include a success field, correlation identity such as
  `itemId` or query ID, payload data on success, and an error message on failure.
- Use `AsyncLifecycle` when responses can arrive after a page changes or a newer
  request supersedes an older one.
- API response data uses Jellyfin's PascalCase field names. Component-owned view
  models may use locally defined lower-camel-case fields.
- Group related component state under a named state object rather than adding
  several unrelated `m.*` variables.

## Media flow

Libraries own loading, filtering, paging, and their grid state. Selecting an item
emits the context required to open a detail page. Detail pages own metadata,
watched state, stream selection, local browse state, and playback selections.
Playback is launched using a selection payload containing the item identity,
media context, resume position, selected streams/mode, and any applicable queue.
Progress and watched-state results flow back as narrow events so the originating
surface can update its data.

`PlaybackController` owns the app-shell lifecycle of the active `VideoPlayer`
node: creation, event wiring, delegated shell commands, restoration snapshot
capture, and teardown. `VideoPlayer` remains the canonical owner of accepted
playback state, Jellyfin playback tasks, queue transitions, and Roku runtime
mechanics. `MainScene` retains page visibility, navigation, focus restoration,
and routing decisions and does not access the player node directly.

## Build and test boundaries

`bsconfig.json` builds the production channel. Pure VideoPlayer helper files are
remapped into `source/video-player-helpers` because multiple SceneGraph components
import them through a shared package path.

`bsconfig-test.json` builds the Rooibos channel. It remaps test specs into the
package's `source/tests` tree and also includes component scripts so `@SGNode`
tests execute against real SceneGraph nodes.

Use these checks:

1. `npm run validate` for the production build.
2. `npm run test:build` for test compilation and packaging.
3. `npm test -- --host <roku-host> --password "<developer-password>"` for the
   full runtime suite on a Roku development device.

Run the device suite for component, observer, focus, field-type, and Roku runtime
behavior. Compilation alone cannot validate those semantics. Keep credentials out
of version control and command examples with real values.

## Generated and local files

`build/`, `out/`, `node_modules/`, local deployment configuration, and logs are
not application source. Preserve unrelated working-tree changes and follow the
special handling for user-owned files documented in `AGENTS.md`.
