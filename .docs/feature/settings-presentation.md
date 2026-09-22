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

Current user categories are Libraries, Media shell, Theme, Playback, TV, and
Screensaver. The Device section sits below all six user categories.

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
