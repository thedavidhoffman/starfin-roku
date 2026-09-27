# Settings presentation

Settings uses sentence case for setting labels, option labels, category names,
library layout row labels, and action labels. Capitalize the first word and
preserve acronyms and proper names, including TV, TMDB, API, Starfin, Roku,
Next Up, and Up Next.

Examples include Account badge, TV episode list scroll, Full screen,
Play next immediately, and Episode thumbnail with logo. Show "Up Next"
retains the capitalization of the named Up Next screen.

This is display text only: registry keys, stored values, defaults, option order,
navigation, and save behavior are unchanged. Exact-text tests should match the
labels; persistence tests continue to assert the existing registry values.

## Theme and Media shell categories

Current user categories are Libraries, Media shell, Theme, Playback, Credits, TV, and
Screensaver. The Device section sits below all seven user categories.

Theme contains the Theme setting with Blue, Black, and Grey in that order,
defaulting to Blue. The account-scoped `theme` registry value stores `blue`,
`black`, or `grey` when Settings closes through the existing save flow.
Reloading settings discards pending edits. Missing or unsupported values fall
back to Blue. The active app background updates when the selection is committed; see
[Themes](themes.md) for colors and account lifecycle behavior.

Media shell contains Media shell background followed by Theme music, restoring
the original label positions at y=0 and y=276 and option lists at y=48 and y=324.
The 72-pixel gap between the first list and the next label contains one centered
horizontal rule: y=239, height=2, width=1040, color `0xF3F7FB33`. Its right edge
aligns with the dialog header rule: the 1560-pixel dialog has 60-pixel inner
margins and the settings panel starts 400 pixels into that inner area.

## Settings dividers

TV, Screensaver, and General use the same 1040-by-2-pixel translucent horizontal
rules as Media shell, aligned to the header rule's right edge. Each is centered
between the preceding option list and the next setting label, without changing
setting positions. TV has two rules (y=177 and y=381); Screensaver has one
(y=239); General has one (y=187). Descriptions stay with their setting and do not
receive separate dividers.

## Credits category

Credits follows Playback and uses the same single-column RadioButtonList as
other categories. Show next episode prompt displays all nine presets at once,
with 52-pixel rows starting at y=48 and its description at y=548. Off is selected
by default. Left returns to the category list; Up/Down navigate the presets and
OK selects the pending value through the normal settings save flow.
Preset labels and stored values are paired in `NextEpisodePromptSeconds.Options()` so
display order and selection mapping come from the same definition.

The user category list displays seven rows. The Device heading and list move
down 50 pixels to y=438 and y=472, retaining the existing row sizes and keeping
all four device categories visible. This adds no nested category or picker.
The description reads: “When Jellyfin hasn’t identified where an episode’s closing credits begin, show the next episode prompt this long before the episode ends.”
See [Next Item Playback](next-item-playback.md#credits-fallback) for behavior.

## Settings normalization

`SettingsStore.GetSettingValue()` owns the existing normalization rules for library
layouts, theme, Home episode images, screensaver type, video streaming mode,
subtitle burn-in, next-item playback, and next-episode prompt seconds. `Load()`
collects stored values and reads them through this function; `Save()` uses it before
writing. Settings consumers use the returned values directly. Independent inputs,
such as selection overrides and pending control edits, retain their own validation.

`SettingsStore.GlobalKeys()` identifies the four device-wide settings: account badge
visibility, video streaming mode, subtitle burn-in, and the TMDB API key. Bulk load
reads them together from `STARFIN_ROKU`; bulk save writes them through one registry
section and flushes once, including when no account is selected. Account settings
remain in their account-specific sections. `LoadGlobal()` and `SaveGlobal()` retain
their existing single-key behavior.

SettingsContent uses the complete normalized snapshot returned by `SettingsStore.Load()`
as its pending settings state and uses `SettingsStore.LibraryKeys()` for library edits.
In General, Down from the last Account badge option focuses the TMDB API-key field;
Up from that field returns to Account badge options and clears the input focus highlight.
