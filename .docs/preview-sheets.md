# Preview Sheets

Jellyfin trickplay previews are stored as preview sheets: a single JPG that contains many small thumbnails arranged in a grid. Each thumbnail inside the sheet represents a timestamp in the video.

Instead of downloading one image per timestamp, the Roku app loads a sheet image and displays one tile from it. SceneGraph does that by setting a `Poster` to the sheet image, then using `clippingRect` and `translation` so only the desired tile is visible.

Example:

```text
sheet 0.jpg
+------+------+------+------+
| 0:00 | 0:10 | 0:20 | 0:30 |
+------+------+------+------+
| 0:40 | 0:50 | 1:00 | 1:10 |
+------+------+------+------+
```

In this model:

- Preview sheet: the full JPG downloaded from Jellyfin.
- Tile: one thumbnail inside that sheet.
- Tile index: the timestamp thumbnail selected from the full trickplay sequence.
- Sheet index: which JPG contains that tile.
- Row/column: where the tile lives inside the sheet grid.

## Starfish Flow

`VideoPlayer` owns the trickplay state. It reads Jellyfin's trickplay metadata, computes which five preview tiles should be shown while scrubbing, and sends those tiles to `PlaybackControls` as `thumbnailData`.

`TrickplayPreloadTask` downloads sheet JPGs into `tmp:/` before they are displayed. This avoids showing remote `Poster` nodes while the image is still loading.

`TrickplayPreviewStrip` renders the five preview slots. It keeps each slot hidden until that slot's `Poster.loadStatus` reports `ready`, which prevents blank black boxes during the first scrub.

The center preview image is larger. The two images on each side are smaller and vertically centered against the main preview image.

## Why This Matters

Without preloading and load-status gating, Roku may show empty poster rectangles for a few seconds when scrubbing starts. The official Jellyfin Roku app avoids that by downloading preview sheets into `tmp:/` and rendering from local files. Starfish follows the same idea in a smaller component structure.
