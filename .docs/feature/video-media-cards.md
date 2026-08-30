# Video Media Cards and Library Layouts

`VideoMediaCard` is the stable grid-item component used by video, collection,
playlist, and Home Media surfaces. Libraries support three presentations:
`poster`, `thumbnail`, and `detailed`. Unknown or removed presentation names
fall back to Poster.

Each of the eight library settings stores its presentation and column count as
one semicolon-delimited value. Valid values are `poster;3` through `poster;6`,
`thumbnail;2` through `thumbnail;4`, and `detailed;2`. Every other value,
including simple presentation names, whitespace, extra fields, and incompatible
counts, resolves to `poster;6`.

The account registry keys use a `*-layout` suffix, such as
`tv-library-layout`, `collection-cards-layout`, and `home-videos-layout`.
Earlier image-type keys are not migrated; a missing current key receives the
canonical `poster;6` default.

The Settings category is named Libraries. Its matrix keeps all eight library
rows visible with Poster, Thumbnail, and Detailed checkbox columns followed by
the compatible column buttons, which reuse the Letter Grid tile treatment.
Selecting a presentation resets its count to the
presentation default. Left from Poster or Back anywhere returns to the category
list.

`LibraryLayoutSetting` owns compound parsing, formatting, defaults, and
validation. `VideoCardGridLayout` owns the corresponding grid cells, image
request sizes, focus assets, and visible-edge calculations. Poster 6,
Thumbnail 4, and Detailed 2 retain their established geometry. Other Poster and
Thumbnail counts resize the artwork while preserving its aspect ratio and the
grid's established horizontal bounds. The three-column Poster layout hides the
secondary metadata label beneath each poster while retaining the title.

Each content node carries the resolved card layout alongside `imageAspect`.
Poster and Thumbnail cards use that geometry for artwork, masks, progress,
watched state, and text. Detailed remains a fixed two-column presentation.

Every Poster and Thumbnail size has a native mask and focus bitmap. Masks use
exact FHD dimensions plus exact two-thirds HD dimensions. Focus bitmaps retain
the logical grid-cell canvas size in both profiles, with separately rasterized
HD curves and border weight so Roku does not rescale the FHD corner pixels.
Asset names identify presentation and configured density, such as
`poster-3-col-focus.png` and `thumbnail-2-col-mask.png`; the `fhd` or `hd`
directory identifies the resolution profile.
Regenerate these assets with `scripts/generate-library-card-assets.ps1`.
