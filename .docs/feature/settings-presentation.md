# Settings presentation

Settings uses a centered 1680px-wide, 900px-high dialog. The category lists and
vertical divider retain their positions; the right-hand panels start at x=400
within the dialog content area and contain 1160px-wide glass cards.

## Launch and category lifecycle

SettingsContent initially constructs category navigation and the Libraries panel.
SettingsDialog assigns the account key, then explicitly loads and applies the full
local settings snapshot once before opening. Content initialization does not read
settings from the registry.

Other panels are layout-only components created when their category first becomes
displayed, including through category-list focus. SettingsContent owns one creation
path for references, card layout, option content, saved values and control observers.
Visited panels remain attached until the dialog closes; switching categories does
not recreate controls or discard edits. There is no background preloading or cache
across dialog sessions.

The full edited snapshot remains independent of panel creation, so closing without
visiting every category preserves unvisited preferences. Subtitle state and language
options received before first visiting Subtitles are retained on SettingsContent and
applied when its panel is created. SettingsDialog retains subtitle requests and the
existing save/failure workflow.

This removes hidden category construction and duplicate settings loading from the
launch path. The first visit to another category incurs its construction cost;
request-to-visible-and-focused timing and category responsiveness require device
measurement before claiming a measured performance improvement.

The dialog heading identifies the displayed category, such as Settings › Libraries
or Settings › Media shell. It remains visible when focus moves into settings or
between pages. SettingsContent publishes categoryTitle through its category-change
path; SettingsDialog reads its initial value and observes changes to update the
existing Dialog title. This experimental presentation adds no passive category
highlight.

## Categories and cards

Current user contains Libraries, Media shell, Theme, Playback, Subtitles,
Credits, TV, and Screensaver. All eight rows are visible. The Device heading is
at y=488 and its three-row list starts at y=522: General, Video, and Advanced.
Category navigation wraps across both lists: Up from Libraries moves to Advanced,
and Down from Advanced moves to Libraries, updating the displayed panel with focus.

Every category uses [SettingsCard](settings-cards.md). Card headings render in
uppercase SmallBoldSystemFont. Options, categories, table rows, and actions use
sentence case, preserving proper names and acronyms such as TV, TMDB, and API.
Descriptions use muted SmallestSystemFont. The native control highlight indicates
focus; cards have no additional focus outline or horizontal divider rules.

SettingsDialog owns its fixed dimensions. SettingsContent owns the card width;
SettingsCard owns the content inset and radio focus overhang.
SettingsContent supplies the width and initializes card layout after
content children exist. SettingsCard derives radio positions and widths while
preserving each page's vertical layout. With a 24px inset and 32px native focus
overhang, radio lists start at x=56 and use 1048px items, leaving equal margins.

Libraries uses one titleless 1160 x 640px card around its unchanged table. The
1045px table is centered at x=57.5 with a 24px vertical inset; all eight rows,
column spacing, controls and navigation remain intact. Credits shows all nine
presets. General retains the API-key text-input focus frame. Advanced keeps its
Reset, Abort and Erase all data confirmation inside one card.

## Subtitle pages and saving

Current user -> Subtitles has two fixed pages: Jellyfin mode and preferred language,
then local per-account burn-in. A bottom-right page number and chevron
indicate navigation; both chevrons appear to the right of the number. Pages use
a short fade. The language picker replaces page one temporarily and Back returns
to Edit without saving. See [account subtitle settings](account-subtitle-settings.md).

Burn-in and other local settings save when Settings closes. Mode and language
save to Jellyfin when closing Settings, before local preferences are saved.
Failures open a separate Retry/Discard/Keep editing confirmation above Settings.
Closing saves block input immediately and delay spinner visuals by two seconds.
Retry retains page-two focus while loading;
completion focuses the mode list or Retry unless the viewer has navigated away.
Mode descriptions follow the focused mode while its list owns focus, otherwise
the saved/pending selection, including pending edits.

## Local preferences and previews

SettingsStore owns normalization and the local snapshot. Account settings include
burn-in; the three device-wide values are account badge visibility, video
streaming mode, and the TMDB API key. The old global burn-in value is ignored
and deleted during normal settings saving, as described in the account subtitle
document. Accounts without a saved burn-in value use During transcoding.

Theme offers Blue, Black and Grey. Theme and watched-indicator changes preview
through the existing dialog events; local persistence still occurs on close.
Media shell uses two pages with standard option fonts and original card padding.
The first contains Movie Layout and Music Layout above TV Series Layout and TV
Episode Layout; the second contains Theme music. Additional settings, page
numbers, chevrons, and a short fade follow the subtitle paging presentation.
Each radio list contains only supported choices;
saved choices and deferred rendering fallbacks are described in
[Media Shell Layout Preferences](media-shell-layout.md). Credits uses
NextEpisodePromptSeconds.Options() for its nine labels and stored values; Off
remains the default. These presentation changes do not alter playback rules.

## Retained experiment references

The glass graphic is generated by scripts/generate-settings-card-assets.mjs.
The earlier solid graphic remains available as images/buttons/fhd/primary-focused.9.png,
with historical tints Blue 0x203957FF, Black 0x282828FF and Grey 0x505050FF.
There is no remaining TV-only theme updater; switching variants would now be a
SettingsCard rendering change.

The original wider-dialog patch is retained at
build/wider-settings-experiment/experiment.patch. It predates the shared-layout
cleanup and is a historical reference, not a patch to reverse blindly against
the current tree. Reversing the experiment now requires restoring a 1040px card
width in SettingsContent and a 1560px dialog width in SettingsDialog, the matching custom input/text widths
and subtitle indicator position, and the unframed Libraries table. Earlier
subtitle functionality and the card redesign must remain intact.

Full runtime suites and UI automation remain deferred during active iteration.

## Badge preferences and TV layout

The Theme category places **Watched indicator** and **Show unwatched episode
count** side by side beneath the full-width Theme choices. SettingsCard measures
its full heading using an unconstrained label; SettingsContent uses those widths
to share spare space equally after both headings. The cards span 1160px with
a 16px gap and remain 240px tall. Count choices are **Off** (default),
**Subtle**, and **High contrast**. Left/Right moves between badge cards; Up from
the first option returns to Theme, and Left from the watched card returns to
categories. Editor focus restoration retains the selected card.

The TV category uses its original full-width single-page layout: **TV episode
list scroll**, **Show season summary card in TV episode list**, then **TV artwork
in "Next Up" and "Continue Watching"**. Paging controls and fades are removed.

Count selections preview through the Settings overlay and persist per account
on close. See [Watched Indicators and Unwatched Episode Counts](watched-indicator.md).
