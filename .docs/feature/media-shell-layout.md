# Media Shell Layout Preferences

Settings > Media shell presents two fixed pages. Page 1 contains Movie Layout
and Music Layout across the top in matching 572-by-292-pixel cards. TV Series
Layout and TV Episode Layout sit below in matching 572-by-240-pixel cards, with
16-pixel gaps. Headings start at 24 pixels; options start at 68 pixels with
52-pixel rows. Lists use the standard settings font and original card padding.
Page 2 contains a full-width 1160-by-188-pixel Theme music card.

Both pages show Additional settings, a page number, and a directional chevron,
following the subtitle settings presentation. Changing pages uses a short fade.
Each layout card lists only its supported options. Choices remain independent
and save through the existing Settings close lifecycle.

| Media | Full backdrop | Corner backdrop | Cinematic | Poster | Registry key |
|---|---|---|---|---|---|
| Movie | Yes | Yes | Yes | Yes | `movie-shell-layout` |
| TV Series | Yes | Yes | No | Yes | `tv-series-shell-layout` |
| TV Episode | Yes | Yes | Yes | — | `tv-episode-shell-layout` |
| Music | Yes | Yes | — | — | `music-shell-layout` |

Full backdrop and Corner backdrop retain runtime values `full-screen` and
`partial-screen`; Cinematic and Poster retain `cinematic` and `poster`.
New accounts default to Full backdrop except TV Series, which defaults to Corner
backdrop. Music currently controls the artist detail page.

## Rendering

Movie and episode pages apply their own settings on load and committed settings
changes. Movie Poster renders a 600-by-900-pixel primary poster at [58.5, 90], leaving
90-pixel top and bottom margins. It uses the regular Starfin background without
movie backdrop artwork, backdrop shading, or the content gradient. Missing or
failed primary artwork uses the standard poster placeholder.

The poster, details, toolbar, and cast share a layout group shifted 37.5 pixels
left in Poster mode, giving the combined visible content equal 58.5-pixel page
margins. Centering uses the five cast cards' 1131-pixel visual span (four
231-pixel strides plus the final 207-pixel text area), excluding the viewport's
21 pixels of trailing space. The right-side details group starts at [730.5, 90].
The toolbar starts at [730.5, 570], and Cast & Crew starts at [730.5, 681]. These elements sit 18 pixels
higher than the original Poster layout; the cast row bounds end at y=993,
3 pixels below the poster bottom at y=990.
Details use a 1056-pixel-wide column. Cast and crew sit below the toolbar in
a 1152-pixel-wide viewport; its five visible card areas end 58.5 pixels from the
screen's right edge. The poster uses a dedicated antialiased 600-by-900-pixel rounded
mask (400 by 600 at HD), avoiding enlargement of the library poster mask. Both remain visible while navigating between
the toolbar and cast. Changing the saved layout restores the appropriate
positions, widths, and background immediately. MediaShell owns the poster and
details rendering; Movie owns toolbar and cast positioning and navigation.

TV Series applies Full backdrop and Corner backdrop as selected. Series
Cinematic is unsupported and normalizes to Corner backdrop; Poster uses the existing large-season-poster layout and focus recovery. As an
experiment, TV Series Poster omits the series backdrop image, black shading,
and bottom content gradient so the current theme background remains visible; switching to
Full backdrop or Corner backdrop restores it. In Poster mode, rows containing
one, two, or three seasons are horizontally centered on the screen. Four or
more seasons retain the existing left-aligned grid and navigation.
The artist page observes committed Music settings and applies the selected backdrop.

TVSeason retains its separate logo-banner and episode-list presentation. Future
season layouts will use the TV Series preference; this stage adds no season rendering.

## Persistence and compatibility

SettingsStore reads the legacy account key `media-shell-background` only when an
independent key is absent. Movies and episodes inherit its backdrop or Cinematic
value; legacy Poster initializes them to Full backdrop. Series inherit Poster, or
Corner backdrop for any other legacy choice. Music inherits Corner backdrop only
when that was the legacy value; other values initialize Full backdrop, preserving
the artist page's prior rendering. This is initial-value migration, not a live
connection between preferences.

New keys override the legacy key. Unsupported values use the row's default;
series reject Cinematic, episodes reject Poster, and Music accepts only the two
backdrop values. Before reading settings, SettingsStore invokes the
[settings migration helper](settings-migrations.md) on every load. It persists
missing layout keys across every existing account, then removes the legacy key
after successful persistence. Read-time compatibility remains available if the
migration fails. Normal saving writes the four independent account keys without
performing legacy cleanup. Settings equality uses the new keys, and no preview
event is added.

## Focus and ownership

SettingsContent owns the radio controls, edited snapshot, and card navigation;
SettingsCard owns card rendering and radio sizing. SettingsStore retains persistence
and normalization. Detail pages consume its normalized layout values directly;
there is no additional movie or series rendering-resolution layer. No matrix
component or matrix event interface remains.

Up/down navigates options within each card. Down from the last Movie option
enters TV Series; Down from the last Music option enters TV Episode. Up from the
first option in either TV card returns to the card above at its last option.
Down from either TV card opens page 2 and focuses the first Theme music option.
Up from that option opens page 1 and returns to the TV card that entered it,
focusing its last option; the initial return target is TV Episode.

Left/right traverses paired cards and preserves the option index, clamping when
needed. Left from a leftmost card or Theme music returns to categories. Right
from a rightmost card or Theme music and vertical movement beyond the outer
pages do not wrap. Entering the category starts on page 1. Focus restoration and
focusLastField show the destination's page. Paging and focus movement preserve
edited selections. SettingsContent owns media paging independently of subtitle
paging; no new public component interface is introduced. Card destinations and
page selection use the named `SettingsNavigation.MediaShellControl` constants
for Movie, Series, Episode, Music, and ThemeMusic; their existing control-array
order remains unchanged.

## Verification coverage

SettingsContent unit tests cover supported choices, independent edits, checkmarks,
card geometry, page visibility and indicators, focus boundaries, return targets,
category reentry, retained edits, and focus restoration. SettingsDialog tests
cover the initial category heading, user and device category changes, and the
heading remaining visible across focus and page changes.

Settings UI automation exercises independent persistence and reopening for every
layout choice, navigation through both pages, return focus from each TV card,
retained checkmarks, page reset on category reentry, and Theme music selection
with remote keys. Heading automation checks every category while its content
has focus.

Movie Poster unit coverage checks artwork and placeholder rendering, backdrop
suppression, right-column dimensions, live restoration, cast navigation, and
primary image requests. Device automation covers initial Poster rendering and
committed live layout changes with the existing cast content retained.

TV Series content and toolbar positioning share one focus-aware path. Applying
committed settings preserves the cast-focused offset for backdrop layouts;
entering Poster restores the regular content offset and recovers season or
toolbar focus when cast or description becomes unavailable. Updated unit
coverage includes these transitions, one-to-three season centering, Movie
group margins, and large season-card presentation.

As a visual experiment, Movie, TV Series, and TV Episode Corner backdrop layouts hide
the black bottom content gradient, including while cast is focused, exposing
more of the main theme gradient. The corner artwork and full-screen shading
layer retain their existing behavior.

Season cards rebind their watched-state observer whenever their content node is
replaced, even when the season ID stays the same during a layout change. Clearing
content detaches the observer. Focused regression coverage checks replacement
nodes in both presentations and Corner backdrop gradient visibility for Movie,
TV Series, and TV Episode, including cast focus and restoration to Full backdrop.

MediaShell derives its mode/media-type flags and detail geometry in one local
layout definition. Artwork, gradient, metadata, and title rendering consume that
definition. Shared backdrop images, shade, gradient, and backdrop URL belong to
its background state; movie-poster state contains only its poster nodes and URL.
Metadata centering uses one positioning path after content or layout changes.
The detail pages retain ownership of toolbar, cast, and season-grid geometry.

## Movie supplemental rows

Movie now positions one supplemental-content region in the former cast slot.
Extras precede Cast & Crew, with only one row visible at a time. The existing
Poster geometry and Cinematic detail visibility apply to the whole region.
MovieSupplementalContent owns row choice and horizontal focus restoration; Movie
owns shell visibility and the Up/Down footer indicators. See
[Movie Extras](movie-extras.md).

Movie's local Layout helper applies explicit Poster, Cinematic, and backdrop
geometry before updating supplemental footer directions and placement. Poster
centers the footer on the translated row viewport; other modes use screen center.
Cinematic Extras with cast below shows a centered Up/Down pair beneath the row;
the last row shows a single centered Up. Backdrop and Poster keep a single arrow.
