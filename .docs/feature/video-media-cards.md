# Video Media Cards and Library Layouts

`VideoMediaCard` is the stable grid-item component used by video, collection,
playlist, and Home Media surfaces. Libraries support three presentations:
`poster`, `thumbnail`, and `detailed`. Unknown or removed presentation names
fall back to Poster.

The wrapper registers its content observer in init() after creating presentation
state and the default card. It then processes any already assigned content.
This avoids an XML onChange callback accessing presentation state before that
state exists. An App Store crash in the 2.2.0 package points to that state access;
the early-callback sequence remains a suspected cause rather than a reproduced
device sequence.

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

The shared watched badge follows the account's [watched indicator style](watched-indicator.md):
Subtle (black with a white check) by default, or High contrast (gold with a black
check). Both backgrounds are opaque. Badge sizing and visibility rules are unchanged.
Poster media cards keep the badge 9 logical pixels from the artwork's top and
right edges. The poster content group has 6 pixels of top padding within the
existing item canvas, giving the focus border room above the artwork. Poster
focus assets extend their lower edge by the same 6 pixels to follow the content.
This applies to default and configurable poster sizes, including library grids
and Home/Search/person shelves. Thumbnail and detailed layouts are unchanged.
Only the rounded outer edge uses transparency for smooth corners.

Every Poster and Thumbnail size has a native mask and focus bitmap. Masks use
exact FHD dimensions plus exact two-thirds HD dimensions. Focus bitmaps retain
the logical grid-cell canvas size in both profiles, with separately rasterized
HD curves and border weight so Roku does not rescale the FHD corner pixels.
Asset names identify presentation and configured density, such as
`poster-3-col-focus.png` and `thumbnail-2-col-mask.png`; the `fhd` or `hd`
directory identifies the resolution profile.
Regenerate these assets with `scripts/generate-library-card-assets.ps1`.

## Explicit text lines and person credits

Every consumer supplies `line1`, optional `line2`, and optional `line3` on the
card's ContentNode. Each line is an assocarray with `text` and `style`, using
`MediaCard.TextStyle.Primary`, `.Secondary`, or `.Muted`. There is no array or
implicit fourth line. Missing or empty lines are hidden. Three-line cards stack only occupied lines
with a consistent 30-pixel step (40 in Detailed); a missing role moves the year
directly below the title without changing the outer item canvas. Existing
two-line cards retain their established positions. `metadataText` and `showMetadata` are removed from the card contract.

Primary uses near-white SmallestBoldSystemFont, Secondary uses light-gray
SmallestSystemFont, and Muted uses subdued blue-gray TinySystemFont. Detailed
cards retain their larger primary title font. Each slot is a ScrollingLabel:
Primary and Secondary scroll on item focus when text overflows; Muted stays
ellipsized. Focus loss stops scrolling. The wrapper forwards item focus to the
active presentation, including after a presentation change. Recycled cards clear
missing lines and reset scrolling.

Consumers use `MediaCardContent.Build` for existing title/year, series-year-range,
and episode-number/title formatting. The renderer does not infer line text from
raw API metadata. Detailed consumers also supply `detailMetadata` for the existing
rating/runtime icon row; a custom plain second line omits that rich row.
`detailMetadata` contains display values only: leading text, runtime text, content
rating, and community/critic ratings. The Detailed presentation builds the
`MediaMetadata` render input and owns width, item spacing, and fitting policy.

Content rendering follows one sequence: the base updates common artwork and
playback state, invokes the presentation to finish its text/layout/visibility,
then applies focus scrolling once. Independent focus changes use that same final
scrolling handler. The common text renderer accepts explicit second-slot hiding
and reservation decisions; it has no knowledge of detailed metadata. Poster owns
its three-column hiding rule; Detailed owns replacement by the rich metadata row.
The larger Detailed title font is declared in its layout and applied during text
rendering, rather than changed after scrolling starts. Overview,
artwork, progress, and watched indicators retain their existing behavior. Library,
Home, Search, collection, playlist, and Home Media grid/row dimensions are unchanged.
The three-column poster presentation continues hiding its second line.

The person page shows its loading spinner immediately (`Spinner.Show(0)`) when a
load starts, without the shared default delay. Completion and failure retain their
existing spinner dismissal behavior.

Person requests `People` with the at-most-40 related movie/series results. Episode
loading first runs the existing at-most-500 discovery query without `People`,
excludes series already represented in the movie/series shelf, and retains at most
40 episodes. Only those retained episode IDs are sent in one additional `People`
request, with images, user data, and total-count calculation disabled. No credit
request is made for an empty shelf. Credits are merged by ID without changing the
original episode order, artwork, or playback data; absent credit results leave
items present without a role. Non-authentication failures in this optional credit
request retain the discovered episodes without roles, so the biography and related
shelves still load. Authentication failures continue through the existing
person-load failure path; required discovery failures also remain fatal. This avoids fetching and parsing hundreds of discarded full casts;
actual latency still requires device measurement.

The page matches `People[].Id` to the requested person and formats their nonempty Role
values without an acting-only prefix. Distinct credits are joined with the shared
bullet separator, for example `Jesse Stone ? Screenwriter`, and duplicate credits
are ignored. Punctuation inside an individual API role is preserved. Missing People, unmatched people, or empty Role values leave
line 2 blank. Line 1 holds the title, line 2 the Secondary role, and line 3 the
Muted production year (or existing series year range). Episode line 1 is the series
name followed by the aggregate season/episode/title string. Missing years leave
line 3 blank. The separate TMDB Filmography list is unchanged.

Person poster items use 297x501 canvases; episode items use 486x384. Each credit
shelf uses a viewport extending from x=76 to the right screen edge: both Person
RowLists are 1844px wide in the 1920px design space. The biography and both focused
layouts retain that horizontal origin; card sizes and spacing are unchanged.
Every item in a shelf reserves the same space even when role or year is absent. The episode shelf
starts at y=596 when movie/series items are present. Its focused page translation
compensates for the added shelf height. The image size and focus outline remain
unchanged; `person-credit-poster-focus.png` and `person-credit-episode-focus.png`
add transparent bottom padding in both resolution profiles. The generator copies
explicit source/destination pixel rectangles; source PNG DPI must not scale or
clip the outline. Regenerate only these
assets with `scripts/generate-person-credit-focus.ps1`. Shared library/Home focus
assets are unchanged.

Functional coverage includes consumer formatting, explicit line styles, focus
scrolling and reset, presentation switching, recycled/empty content, person role
matching and missing data, aggregate episode text, and People request fields.
Device verification of scrolling, three-line spacing, and focus alignment is
required when the development cycle is closed; source review alone does not verify
SceneGraph rendering.
