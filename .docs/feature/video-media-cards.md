# Video Media Cards

`VideoMediaCard` is the stable grid-item component used by video, collection,
playlist, search, person, and Home Media surfaces. Its `itemContent.imageAspect`
field selects one concrete presentation without requiring owning grids to replace
their `itemComponentName`.

The reusable media-card family lives under `components/pages/Video/Cards`.
Feature-owned cards, such as season and episode cards, remain with the page that
owns their behavior.

The supported presentation mapping is:

- `poster` (and unknown values): `VideoPosterCard`
- `thumbnail`: `VideoThumbnailCard`
- `jumbo`: `VideoJumboCard`
- `detailed`: `VideoDetailedCard`

Production code references these persisted string values through
`VideoCardPresentation.Type`. `VideoCardPresentation.Normalize()` is the
canonical boundary for settings or other dynamic input and falls back to Poster
for absent or unknown values.

`VideoMediaCardBase` owns the shared artwork, artwork background, watched
indicator, playback progress, placeholder, and shared node layout contract.
Concrete presentation components inherit that behavior and own their fixed
geometry and presentation-specific text, logo, or overview rendering.

The wrapper creates only the active presentation. When a recycled grid item
changes aspect, it replaces the concrete child and forwards the current
`itemContent`. This keeps the grid-facing contract stable without retaining four
hidden card trees per cell.

`VideoCardGridLayout` separately owns the parent grid's cell geometry, spacing,
focus assets, image-request dimensions, and edge calculations. Cards own only
the presentation inside an individual grid cell.
