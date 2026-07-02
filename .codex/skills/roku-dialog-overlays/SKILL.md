---
name: roku-dialog-overlays
description: Create, refactor, or debug Dialog-based overlays in this Roku app, including Dialog subclasses, contentComponentName content controls, nested dialog directories, OverlayHost request payloads, MainScene routing, close events, and focus/selection return behavior.
---

# Roku Dialog Overlays

Use this skill when adding or changing a custom dialog, picker, media option panel, or overlay launched above the app shell.

## Core Rule

Feature dialogs should extend the shared `Dialog` component and be opened through the top-level `OverlayHost` when their backdrop must cover the header and current page.

- Let `components/controls/Dialog` own the frame, backdrop, title, panel position, content host, buttons, and common close handling.
- Let the feature dialog own configuration, payload wiring, content observation, and feature-specific close/save behavior.
- Let the content component own UI controls, item rendering, focus movement, and local selection state.
- Let `OverlayHost` own top-level z-order, overlay lifetime, close-field observation, and returning the closed overlay plus request to `MainScene`.

## Directory Pattern

Keep each dialog/content pair under the feature folder:

```text
components/pages/<Feature>/<DialogFamily>/<FeatureDialog>/<FeatureDialog>.xml
components/pages/<Feature>/<DialogFamily>/<FeatureDialog>/<FeatureDialog>.brs
components/pages/<Feature>/<DialogFamily>/<FeatureContent>/<FeatureContent>.xml
components/pages/<Feature>/<DialogFamily>/<FeatureContent>/<FeatureContent>.brs
```

Examples:

- `components/pages/Settings/SettingsDialog/SettingsDialog.xml`
- `components/pages/Settings/SettingsContent/SettingsContent.xml`
- `components/pages/Library/LetterGrid/LetterGridDialog/LetterGridDialog.xml`
- `components/pages/Library/LetterGrid/LetterGridContent/LetterGridContent.xml`
- `components/pages/MediaToolbar/AudioOptions/AudioOptionsDialog/AudioOptionsDialog.xml`
- `components/pages/MediaToolbar/AudioOptions/AudioOptionsContent/AudioOptionsContent.xml`

Nest item components under the same dialog family when they are only used there, such as `LetterGrid/LetterGridItem`.

## Dialog Subclass

Make the dialog XML extend `Dialog` directly:

```xml
<component name="ExampleDialog" extends="Dialog">
  <script type="text/brightscript" uri="pkg:/components/pages/Example/ExampleDialog/ExampleDialog.brs" />
  <interface>
    <field id="selectedItem" type="assocarray" alwaysNotify="true" />
    <function name="openExample" />
  </interface>
</component>
```

In the open function, configure inherited fields, pass payload to content, observe content events, then call inherited `openDialog`:

```brightscript
sub openExample()
    m.top.title = "Example"
    m.top.dialogWidth = 540
    m.top.dialogHeight = 562
    m.top.contentComponentName = "ExampleContent"

    content = m.top.callFunc("getContentComponent")
    content.items = m.top.items
    content.observeField("itemSelected", "onContentItemSelected")

    m.top.callFunc("openDialog")
    content.callFunc("focusItems")
end sub
```

Use `onCloseRequested()` in the dialog script when the dialog must publish saved settings or final state before `closeRequested` is emitted. `Dialog.closeDialog()` calls this hook before setting `m.top.closeRequested = true`.

## Content Component

Put repeated controls, lists, grid tiles, focus movement, and OK/select handling in `<FeatureContent>`.

- Emit event fields with the selected value, such as `letterSelected`, `subtitleSelected`, or `audioSelected`.
- Provide focus helpers such as `focusItems()` or `focusFirstField()` when the dialog needs to enter content focus after opening.
- Keep content layout relative to Dialog's content host. The content origin is based on `panelX + 60`, `panelY + 170`; use local translations only to preserve the intended visual position.

## Launch Flow

For dialogs that should sit above the header and all page content, the owning page should emit a narrow `assocarray` request field instead of embedding the dialog as a child:

```brightscript
m.top.overlayRequested = {
    id: "example",
    componentName: "ExampleDialog",
    openFunction: "openExample",
    closeField: "closeRequested",
    items: m.items
}
```

Use `closeFields` when the overlay can close through more than one repeatable event field.

`MainScene` observes the page event and calls:

```brightscript
m.overlayHost.callFunc("openOverlay", request)
```

When `OverlayHost.closed` fires, route results by `request.id` back to the owning page or active media surface. Keep this routing high-level and event-like.

## OverlayHost Contract

`OverlayHost.openOverlay(request)`:

1. Closes the currently active overlay.
2. Creates `request.componentName`.
3. Copies known request payload fields onto the overlay in `applyOverlayRequestFields`.
4. Observes `request.closeField` or each field in `request.closeFields`.
5. Appends the overlay to `OverlayHost`.
6. Calls `request.openFunction`.

When a new overlay needs payload fields, update `applyOverlayRequestFields` with a narrow `request.id` branch. Do not make pages reach into overlay internals or parent chains.

## Embedded Dialogs

Only embed a dialog as a page child when the backdrop intentionally belongs below app-shell chrome. If the backdrop should cover the header, open it through `OverlayHost`.

## Checklist

When adding or refactoring a dialog:

1. Create `<FeatureDialog>` extending `Dialog`.
2. Create `<FeatureContent>` for the controls and focus logic.
3. Put both component file pairs in nested subdirectories under the feature folder.
4. Add content fields/events needed by the dialog.
5. Add an `overlayRequested` event to the owning page if the overlay should be top-level.
6. Route the request through `MainScene` to `OverlayHost`.
7. Add a narrow payload branch to `OverlayHost.applyOverlayRequestFields` when needed.
8. Route `OverlayHost.closed` results back to the owner by `request.id`.
9. Run `npm run validate`.

## Common Mistakes

- Do not wrap a child `<Dialog>` inside a feature component that extends `Group` when the feature can extend `Dialog` directly.
- Do not define a feature `init()` that prevents the base `Dialog` initialization from running.
- Do not keep overlay dialogs embedded inside pages if the header should appear behind the backdrop.
- Do not add broad generic payload copying to `OverlayHost`; copy only known fields for known overlay ids.
- Do not put list/grid focus logic in `MainScene` or `OverlayHost`; keep it in the content component.
