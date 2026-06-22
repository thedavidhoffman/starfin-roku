---
name: media-toolbar-dynamic-buttons
description: Build, extend, or debug the Roku MediaToolbar and DynamicButton pattern in this repo, especially icon-only collapsed buttons, focused expanded buttons with text, toolbar-owned sibling layout, focus movement, and button spacing/width issues.
---

# MediaToolbar Dynamic Buttons

Use this skill when working on `components/pages/MediaToolbar` or any toolbar that uses the same `DynamicButton` behavior.

## Core Rule

Let `DynamicButton` own its own visual state, but let `MediaToolbar` own sibling layout.

- `DynamicButton` decides whether it is collapsed or expanded from focus state.
- `DynamicButton` changes its background, icon, text visibility, and background width.
- `MediaToolbar` computes each button's `translation` based on the currently focused button.
- Do not hard-code later button x positions in XML once buttons can expand and collapse.

## Current Pattern

`DynamicButton` uses:

- collapsed background width: `64`
- focused/expanded width: `expandedWidth` field, or the component default
- icon-only display when unfocused
- icon plus text display when focused

`MediaToolbar` uses:

- `m.focusState.focusedIndex` as the source of truth
- `m.focusState.buttons` as the ordered button list
- `layoutButtons()` before focusing the target button
- collapsed sibling width `64`
- a small fixed gap between buttons

## Layout Algorithm

When focus moves, recompute every button position from left to right:

```brightscript
x = 0
for i = 0 to m.focusState.buttons.Count() - 1
    button = m.focusState.buttons[i]
    button.translation = [x, 0]

    if i = m.focusState.focusedIndex then
        x = x + getButtonExpandedWidth(button)
    else
        x = x + m.toolbarLayout.collapsedWidth
    end if

    x = x + m.toolbarLayout.buttonSpacing
end for
```

This means:

- If button 1 is focused, button 2 starts after button 1's expanded width.
- If button 2 is focused, button 2 shifts left after button 1's collapsed width.
- Buttons after the focused button shift right to make room for the expanded text.
- Buttons before the focused button remain compact unless they are the focused one.

## Adding Buttons

When adding a button:

1. Add the `DynamicButton` in XML without a fixed `translation`.
2. Set `icon`, `focusedIcon`, `text`, and `expandedWidth`.
3. Add the node reference in `MediaToolbar.brs`.
4. Add it to `m.focusState.buttons` in display order.

Example:

```xml
<DynamicButton
  id="exampleButton"
  icon="pkg:/images/icons/example-light.png"
  focusedIcon="pkg:/images/icons/example-focused.png"
  text="Example"
  expandedWidth="220" />
```

## Focus Behavior

Keep focus routing in the toolbar:

- `left`: focus the previous button.
- `right`: focus the next button.
- `down`: emit `focusExitDown`.
- `OK` / `select`: let `DynamicButton` emit its own selection event.

Call `layoutButtons()` whenever `focusedIndex` changes, before calling `setFocus(true)` on the selected button.

## Common Mistakes

- Do not leave `translation="[...]"` on later buttons in XML; it will fight the computed layout.
- Do not make every button expanded; only the focused button should reveal text.
- Do not put sibling positioning in `DynamicButton`; it should not know about other toolbar items.
- Do not duplicate the collapsed width in multiple places without checking the `DynamicButton` background width.
- If a focused button's text clips, increase that button's `expandedWidth` in `MediaToolbar.xml` rather than changing the toolbar algorithm.
