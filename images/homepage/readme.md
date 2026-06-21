# HomePage Mask Images

These images are used by HomePage item rendering and focus artwork. The names
are easy to mix up because the visible thumbnail size and the focus canvas size
are different.

## `home-page-thumbnail-mask-440x248.png`

Rounded mask for the actual wide thumbnail image.

Used by `HomeGridItem` when `imageAspect = "wide"`:

- `My Media`
- `Continue Watching`
- `Next Up`

## `home-page-my-media-thumbnail-focus-485x306.png`

Focus bitmap for the `My Media` row.

This row uses wide thumbnails but has only one label, so its item canvas is
shorter than the other wide rows.

## `home-page-thumbnail-focus-485x348.png`

Focus bitmap for wide HomePage rows with two labels.

Used by rows:

- `Continue Watching`
- `Next Up`

## `home-page-poster-mask-250x375.png`

Rounded mask for the actual poster image.

Used by `HomeGridItem` when `imageAspect = "poster"`.

## `home-page-poster-focus-295x463.png`

Focus bitmap for poster-style HomePage rows.

Used by rows that display taller poster images instead of wide thumbnails.
