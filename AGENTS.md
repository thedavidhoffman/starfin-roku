# AGENTS.md

## Roku reference

- https://github.com/rokudev/samples
- https://developer.roku.com/en-au/docs/references/references-overview.md

## Roku XML style

- Prefix literal XML color values with `0x`, such as `color="0xF3F7FBFF"`.
- Use dash-case for image filenames, such as `star-rating.png`; do not use underscores in new image filenames.

## BrightScript style

- Assign color fields with integer hex literals, such as `m.title.color = &h0F1A2AFF`, not string values like `"0x0F1A2AFF"`.
- Do not use `FormatJson()` for outbound API request bodies. Roku lowercases JSON object keys during serialization, which breaks case-sensitive API fields.
- API response fields are PascalCase; access API data with PascalCase field names such as `item.CollectionType`, not mixed fallback expressions like `FirstNonEmpty([item.CollectionType, item.collectionType], "")`.
- For date or time formatting/parsing helpers, use the existing functions in `source/DateTime.brs`; add new shared date helpers there instead of creating component-local date formatting functions.

## BrightScript naming

- Use module-style function prefixes, such as `AuthStore_Load` or `Playback_Start`, for shared helpers under `/source`.
- For helpers under `/source` that are internal to a single file, use a leading `__` prefix instead of the public module prefix, such as `__GetCollapseSeriesQueryValue`.
- Do not use module-style prefixes for component-local functions in `components/`; name those functions by their local behavior, such as `initStyle`, `onKeyEvent`, or `colorString`.

## SceneGraph architecture

- Keep `MainScene` focused on app-shell orchestration: top-level visibility, routing between major surfaces, global focus recovery, and app exit handling.
- Set app-level status through `source/Status.brs` helpers (`Status_SetLoading`, `Status_SetMessage`, `Status_ClearMessage`) using the shared `StatusLabel`; do not add page-local status labels for surfaces that can use the shared app-shell status message. `Status.brs` depends on component context through `m.top`, so use it only from component scripts, not tasks or pure source modules. Do not access shared status through parent chains such as `m.top.top.statusLabel`. Clear stale shared status during app-shell navigation and dynamic page close/reset flows instead of adding page-local cleanup labels.
- Prefer putting feature-specific API tasks, response handling, local loading state, and local navigation state inside the component that owns that feature. For example, Library should own library loading/drilldown, HomePage should own personalized shelf loading, Player should own playback session requests, and auth/session persistence should live in an auth-focused controller rather than in `MainScene`.
- Component-to-`MainScene` communication should be narrow and event-like: selected item, auth error, close requested, or a completed high-level action. Avoid bubbling low-level task requests through `MainScene` when the originating component can own the task safely.
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
