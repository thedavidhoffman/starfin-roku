# AGENTS.md

## Project overview

- Read `ARCHITECTURE.md` before making architectural changes or moving responsibilities between components, tasks, controllers, and shared source helpers.

## Roku reference

- https://github.com/rokudev/samples
- https://developer.roku.com/en-au/docs/references/references-overview.md

## User-owned files

- Treat `.to-do.md` as user-owned scratch content. Do not modify it, and ignore its working-tree changes during status checks and code reviews unless the user explicitly asks to review or edit it.

## Roku XML style

- Prefix literal XML color values with `0x`, such as `color="0xF3F7FBFF"`.
- Use dash-case for image filenames, such as `star-rating.png`; do not use underscores in new image filenames.

## BrighterScript style

- Assign color fields with integer hex literals, such as `m.title.color = &h0F1A2AFF`, not string values like `"0x0F1A2AFF"`.
- Do not use `FormatJson()` for outbound API request bodies. Roku lowercases JSON object keys during serialization, which breaks case-sensitive API fields.
- API response fields are PascalCase; access API data with PascalCase field names such as `item.CollectionType`, not mixed fallback expressions like `FirstNonEmpty([item.CollectionType, item.collectionType], "")`.
- For date or time formatting/parsing helpers, use the existing functions in `source/DateTime.bs`; add new shared date helpers there instead of creating component-local date formatting functions.
- For numeric conversion, always use `Number.ToInteger(value, fallback)` and `Number.ToFloat(value, fallback)` from `source/Number.bs`. Do not use raw `int()`, `Val()`, or direct float casts in component or task code unless there is a specific documented reason.
- Always invoke SceneGraph interface functions with `node.callFunc("functionName", ...)`.
- Do not use BrighterScript's `node@.functionName(...)` syntax. Zero-argument calls have caused runtime argument and type failures despite passing compilation.

## BrighterScript naming

- Put shared helpers under `/source` in a namespace named for their responsibility, and call public members through that namespace, such as `AuthStore.Load()` or `PlaybackProgress.GetTicksFromItem()`.
- Name public namespace members in PascalCase without repeating the namespace in the member name.
- For namespace helpers that are internal to a single file, use a leading `__` prefix, such as `__GetCollapseSeriesQueryValue()`.
- Component-local functions in `components/` are not namespace members; name them by their local behavior in lower camel case, such as `initStyle`, `onKeyEvent`, or `colorString`.

## Unit tests

- Give each distinct test case or behavior its own test. Do not combine multiple test cases into a single test function.
- Place test files in directories that mirror the production source-code directory structure.
- Format BrighterScript unit-test suites with one blank line after the `namespace` declaration, between the suite/class header and each `@describe`, after each `@describe`, between every test function, before `end class`, and between `end class` and `end namespace`.
- Within a test function, use blank lines intentionally to delineate setup, action, assertion groups, and other distinct test steps. Preserve these meaningful internal blank lines when normalizing suite-level spacing.
- When changing a file with an existing corresponding unit-test suite, update that suite to cover the changed behavior.
- Do not modify production source code or expand production interfaces solely to make a unit test possible or pass. Adapt the test to existing production behavior and boundaries. If a new unit test reveals a genuine production bug, stop and report the bug instead of silently changing production code as part of the test work.
- Run the relevant unit tests after making the change.
- A successful test build does not verify SceneGraph runtime behavior. When tests exercise components or Roku behavior, run the full Rooibos suite on the configured development device and iterate until it passes.
- Run device tests with `npm test -- --host <roku-host> --password "<developer-password>"`. Do not commit the developer password or place it in command examples with a real value.
- If no test change is necessary, verify that the existing tests still cover the behavior and mention that in the final response.

## Workspace hygiene

- Treat unrelated pending changes as user-owned or concurrent work. Preserve them, do not reformat or revert them, and scope reviews and verification to the requested work.
- Generated output belongs under `build/` and `out/`; do not treat generated files there as source changes.

## SceneGraph architecture

- When a component `init()` grows beyond simple orchestration because it contains substantial node lookup or observer registration, extract those responsibilities into `initReferences()` and `initHandlers()` and keep `init()` focused on initialization sequencing.
- Keep `MainScene` focused on app-shell orchestration: top-level visibility, routing between major surfaces, global focus recovery, and app exit handling.
- Set app-level status through `source/Status.bs` helpers (`AppStatus.SetLoading`, `AppStatus.SetMessage`, `AppStatus.ClearMessage`) using the shared `StatusLabel`; do not add page-local status labels for surfaces that can use the shared app-shell status message. `Status.bs` depends on component context through `m.top`, so use it only from component scripts, not tasks or pure source modules. Do not access shared status through parent chains such as `m.top.top.statusLabel`. Clear stale shared status during app-shell navigation and dynamic page close/reset flows instead of adding page-local cleanup labels.
- Prefer putting feature-specific API tasks, response handling, local loading state, and local navigation state inside the component that owns that feature. For example, Library should own library loading/drilldown, HomePage should own personalized shelf loading, Player should own playback session requests, and auth/session persistence should live in an auth-focused controller rather than in `MainScene`.
- Component-to-`MainScene` communication should be narrow and event-like: selected item, auth error, close requested, or a completed high-level action. Avoid bubbling low-level task requests through `MainScene` when the originating component can own the task safely.
- For custom dialogs, prefer a feature dialog component that extends `components/controls/Dialog` directly, plus a separate content component mounted through `contentComponentName`. Put each dialog/content file pair in its own subdirectory under the feature folder. Dialogs that should cover the header and current page must be launched through the top-level `OverlayHost`; pages should emit a narrow `overlayRequested` assocarray and `MainScene` should route the request to `OverlayHost`. See the repo skill `.codex/skills/roku-dialog-overlays/SKILL.md` for the full pattern.
- For repeatable SceneGraph event fields, prefer `type="boolean"` with `alwaysNotify="true"` over integer counters. For repeatable events that need payload data, use the payload type (such as `assocarray`) with `alwaysNotify="true"` rather than adding a synthetic `counter` field. Keep counters only when the number itself is meaningful or needed for async request/response correlation.
- Pass session context down as explicit request data (`server`, `token`, `bookLibraryId`) instead of letting child components read global scene state.
- Do not add defensive `invalid` checks around required XML child nodes after `findNode()` when the component owns that XML and the node should always exist. Let missing required nodes fail loudly instead of hiding structural mistakes. Reserve `invalid` checks for optional nodes, dynamic children, cross-component references, or data that can legitimately be absent.
- When adding component variables, group two or more conceptually related values into a named state object instead of leaving them as separate loose `m.*` fields. When adding a new variable or changing an existing one, review the component's variable list for new grouping opportunities.
- Extract shared pure logic into `/source` helpers when it is reused or when keeping it in a component would make the component responsible for unrelated calculations. Avoid abstractions that only replace one clear local boolean or one obvious call site.
- After each architectural move, run validation before continuing so boundary mistakes are caught while the change is still small.

## Commenting Style

- Add a three-line comment header immediately above each function definition in `src/config.js`.
- Line 1 must be `'` followed immediately by dashes, extending to the 80th column with no space before the first dash.
- Line 2 must be `' ` followed by the exact function name.
- Line 3 must match line 1 exactly.
