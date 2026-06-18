---
name: roku-rowlist-focus
description: Build or debug animated Roku SceneGraph RowList focus highlights, especially custom focusBitmapUri assets for mixed item sizes, thumbnail/poster rows, padded focus canvases, and alignment issues where the highlight is offset or inset from the visible image.
---

# Roku RowList Focus

Use this skill when implementing or fixing animated `RowList` focus highlights in Roku SceneGraph.

## Core Rule

Keep animated focus on the `RowList` when the highlight should glide between items.

- Use `drawFocusFeedback="true"`.
- Use `focusBitmapUri` for the custom highlight artwork.
- Use `focusFootprintBitmapUri=""` when no default footprint should show.
- Avoid drawing the highlight inside each item component if the desired behavior is native RowList focus movement; component-local `itemHasFocus` rings usually appear/disappear instead of gliding.

## Geometry Pattern

The focus bitmap is positioned by the `RowList` relative to the row item canvas, not relative to the visible thumbnail/poster alone.

For a reliable custom focus:

1. Make the focus PNG canvas match the full `rowItemSize`.
2. Draw the visible ring at the same coordinates where the image appears inside the item component.
3. If the image component is inset inside a `contentGroup`, the ring in the PNG must use the same inset.
4. If the ring needs breathing room outside the image, increase `rowItemSize` and inset the item content; do not just add transparent padding to the PNG.
5. If increasing `rowItemSize` changes visual gaps, compensate with `rowItemSpacing`.

## Working Example From This Repo

`TVSeason` works because the item canvas and focus bitmap agree:

- `TVSeason.xml` uses `rowItemSize="[[575,590]]"`.
- `TVEpisodeItem.xml` uses `contentGroup translation="[20,0]"`.
- The thumbnail mask is inside that group at `translation="[0,38]"` with size `530x298`.
- The focus asset is `rounded-episode-thumbnail-focus-575x590.png`.
- The ring is drawn inside the `575x590` canvas around the translated thumbnail area, not around a standalone `530x298` image at origin.

For HomePage, use the same structure:

- Add a content group around image and labels, such as `translation="[20,0]"`.
- Increase row item widths to include the padded focus canvas.
- Keep visible image sizes unchanged.
- Use a negative or reduced `rowItemSpacing` if needed so visible image-to-image spacing remains unchanged.

## Mixed Row Types

If one `RowList` contains multiple item layouts, swap `focusBitmapUri` when `rowItemFocused` changes.

Recommended pattern:

```brightscript
m.homeRows.observeField("rowItemFocused", "onHomeRowItemFocused")

sub onHomeRowItemFocused()
    focused = m.homeRows.rowItemFocused
    if focused = invalid or focused.Count() < 1 then return

    row = m.homeRows.content.getChild(focused[0])
    if row = invalid then return

    m.homeRows.focusBitmapUri = getFocusBitmapUriForRow(row.rowKey)
end sub
```

Store a stable row key on each row `ContentNode` so focus selection is based on row semantics, not row index guesses:

```brightscript
content.AddFields({ rowKey: key })
```

For smoother vertical movement, prefer pre-swapping the target row's focus bitmap in a custom `RowList` subclass on `up` / `down` keypress, then return `false` so Roku still performs the native move.

If changing between different aspect-ratio rows still hops, keep the visible item image sizes different but normalize the focus bitmap canvas width across those row types. Use per-row `rowItemSpacing` to preserve the visible image-to-image gap. This avoids resizing the RowList focus node horizontally during the animation.

If a mixed-layout `RowList` still jitters, split the page into one single-row `RowList` per shelf. Each shelf owns a fixed `focusBitmapUri`, so Roku never swaps or resizes the focus node between aspect-ratio families. Keep native horizontal animation inside each shelf and implement vertical shelf focus transfer/scrolling in the parent component.

## Image Asset Checks

Before deciding a mask is wrong, inspect the actual non-transparent bounds:

```powershell
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile("images\masks\focus.png")
```

Confirm:

- PNG width and height match the referenced `rowItemSize`.
- Non-transparent bounds line up with the image location inside the item component.
- The ring is not drawn at `x=0` if the item image is inset.
- The ring is not inset into the visible image unless that is intentional.

## Common Mistake

Do not copy transparent padding from a working focus PNG without also copying the item layout that makes the padding correct.

If a working item has `contentGroup translation="[20,0]"` and the new item image starts at `x=0`, copying the same padded focus bitmap will make the ring look offset or inset.
