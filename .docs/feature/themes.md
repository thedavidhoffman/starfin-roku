# Themes

The current release supports Blue, Black, and Grey. Additional colors are deferred
until a future release.

## Preference and active state

Settings > Current user > Theme offers Blue, Black, and Grey. The existing
account-scoped `theme` registry key remains the persisted source. Selecting an option immediately previews it across the visible UI, including
the Settings dialog. Moving focus alone does not preview. Closing Settings with
Back commits the selection as before; there is no separate Cancel button.
Programmatic dismissal or replacement discards edits and restores the current
session theme (Blue on the login screen).

Startup creates `global.theme` as a string with `blue` before MainScene and its
children are created. MainScene owns subsequent writes through `syncTheme`:

- Initial settings use Blue before a user is authenticated.
- Login, session restoration, and successful account switches load the account's
  saved theme through `navShowApp` and `fanOutSettings`.
- Committed settings update through the existing overlay-close/fan-out path.
- Returning to login after logout or session expiry restores Blue.
- Resetting application data restores Blue.
- Failed account switches keep the current user's background while the app
  remains authenticated.

Missing, empty, or unsupported themes normalize to Blue. Reassigning the same
value leaves the current rendering unchanged. Background components only read and
observe global theme state; they do not load or save registry preferences.

## ThemeBackground

`components/controls/ThemeBackground/` contains a nonfocusable Group with width
and height fields, defaulting to 1920 by 1080. MainScene uses one instance in place
of its former background Rectangle and Poster. Both layers resize together.

| Theme | Rendering |
| --- | --- |
| Blue | Existing `pkg:/images/themes/blue/background.png` with `scaleToFill`, over opaque black |
| Black | `images/themes/black/background.png`: near-black to softly lifted charcoal |
| Grey | `images/themes/grey/background.png`: darker charcoal to softly lifted dark grey |

All three themes show a 1920-by-1080 gradient image using `scaleToFill`.
The Rectangle stays opaque beneath the Poster, retaining the theme color
(Blue: black; Black: `#121212`; Grey: `#343434`) while images load. The
component reads the active theme immediately and observes subsequent changes, so
new instances and existing backgrounds agree. Image paths, color constants, and normalization
live in `source/Theme.bs`.

This stage themes the app-shell background and both header dropdown menus, and shared dialog panels.
General page labels, the header navigation strip and
page-specific artwork retain their existing styling; ThemeLabel is future work.
The legacy Theme.Get palette remains unchanged.

## Asset layout and header dropdowns

Each `images/themes/{blue,black,grey}/` directory contains:

- `background.png`: the fullscreen gradient.
- `square-button-background.png`: the 64px SquareButton tile.
- `header-menu-fill.9.png` and `header-menu-glass.9.png`: menu master assets.
- `dialog-panel.9.png`: dialog master, retaining the original white border.
- `fhd/` and `hd/`: resolution-specific copies of all three nine-patch assets.

Shared focus graphics, icons, and masks stay in their existing directories.
Blue assets were moved unchanged. All consumers of moved assets were updated,
including the MainScene backdrop and the header navigation glass. Up Next uses
MainScene's background rather than a separate backdrop.

`Theme.BackgroundUri` resolves the fullscreen image. `Theme.HeaderMenu` resolves
both menu images using the active resolution and supplies identity text, divider,
and focused text colors. Both header menus use the same HeaderDropdownMenu
component, which reads global theme at initialization and observes changes.
It updates existing item buttons instead of rebuilding the list, preserving the
open state, focused item, and selection events. Newly rendered buttons also use
the current palette. Menu identity text and unfocused item text stay white.
Focused text is dark blue for Blue, off-black for Black, and charcoal for Grey,
against the shared white focus graphic. Divider colors are pale blue for Blue and
neutral white for Black/Grey, at the existing opacity.

Run `scripts/generate-resolution-button-assets.ps1` to rebuild FHD/HD assets from
the masters, or pass `-ValidateOnly` to check their geometry. The generator now
includes all three themes. Black/Grey masters preserve Blue's exact alpha channel
and all nine-patch marker borders; their interiors use the generated materials.
The neutral glass material is shared visually by Black and Grey. Generated-image
corners and marker approximations are not used. Verification includes comparing
alpha/marker pixels and checking a stretched composite preview.


## Gradient asset generation

Black and Grey were generated with the built-in image generation tool, using
the existing Blue image as the reference. The generated images were resized to
1920 by 1080 PNGs for the app. Blue remains unchanged.

Black prompt:

> Use case: style-transfer. Asset type: fullscreen Roku TV UI background bitmap. Reference/edit target: attached existing Blue gradient. Create a BLACK theme sibling, preserving the smooth subtle spatial gradient layout: almost black at top, softly lighter charcoal toward bottom and lower center, quiet darker edges. Neutral grayscale only. Restrained values approximately #090909 at top/edges to #202020 at lightest lower center. Pure smooth gradient, no objects, no texture, no shapes, no text, no watermark, no bright hotspot, no border. Keep the reference's understated seamless appearance and 16:9 landscape framing. Output 1920x1080 PNG.

Grey prompt:

> Use case: style-transfer. Asset type: fullscreen Roku TV UI background bitmap. Reference/edit target: attached existing Blue gradient. Create a GREY theme sibling preserving the smooth subtle spatial gradient layout: darker charcoal at top and edges, softly lighter dark grey toward bottom and lower center. Neutral grayscale only. Restrained values approximately #252525 at top/edges to #414141 at lightest lower center. Clearly a dark grey theme, softer and lighter than near-black but never light grey. Pure smooth gradient, no objects, no texture, no shapes, no text, no watermark, no bright hotspot, no border. Keep the reference's understated seamless appearance and 16:9 landscape framing. Output 1920x1080 PNG.

## Verification

Menu asset prompts (built-in image generation; interiors applied to the original
nine-patch alpha and marker geometry):

Black fill:

> Create a BLACK theme version of this tiny Roku nine-patch glass menu fill. Recolor the interior navy to uniform neutral off-black #121212, keep geometry otherwise unchanged. No added details, text, shadows or effects. This is a flat UI texture asset. Original transparent corners and one-pixel stretch marker frame must be preserved. Output PNG.

Grey fill:

> Create a GREY theme version of this tiny Roku nine-patch glass menu fill. Recolor the interior navy to uniform neutral dark grey #343434, keep geometry otherwise unchanged. No added details, text, shadows or effects. This is a flat UI texture asset. Original transparent corners and one-pixel stretch marker frame must be preserved. Output PNG.

Neutral glass for both:

> Create a neutral grayscale version of this glass UI background texture. Change only its pale blue interior tint to pale neutral grey #E8E8E8, retaining the bright white rim and soft translucency. No text, no added texture, no drop shadow. Supporting reference is the existing Roku nine-patch glass overlay. This will be resampled into the original nine-patch geometry, so keep the broad interior evenly pale grey. Output a PNG.


Component coverage checks initialization, all theme colors, fallback, repeat
assignments, switching back to Blue, and sizing. MainScene coverage checks saved
settings propagation, account loading/switching, ignored uncommitted edits, login,
and reset. The test root scene creates the same global theme field before test
components are constructed. Runtime visual and observer verification requires
explicitly requested device tests; compilation does not verify those behaviors.

## Dialog panels

The shared Dialog component reads global.theme on initialization and observes
changes. Theme.DialogPanelUri resolves the active theme and resolution. Updating
the panel URI preserves content, layout, visibility, and focus; subclasses inherit
this behavior. Blue uses the original unchanged panel. Black uses #191919 and
Grey uses #3D3D3D. White border pixels, alpha, corners, and stretch markers are
preserved from the original; only the interior and its border blending change.

Assets are saved as images/themes/{blue,black,grey}/dialog-panel.9.png and the
corresponding fhd/hd variants. Built-in image generation supplied the neutral
interior samples, which were applied to the original pixel geometry.

Black prompt:

> Use case: precise-object-edit. Asset type: Roku dialog nine-patch panel. Create a BLACK theme equivalent of this existing dialog frame. Change ONLY the navy interior to uniform neutral #181818. Preserve the white border, rounded corners, transparency and original geometry. No new shapes, gradients, textures, shadows, text or highlights. The final production asset will reuse the original exact border/mask and use your interior material. Output PNG.

Grey prompt:

> Use case: precise-object-edit. Asset type: Roku dialog nine-patch panel. Create a GREY theme equivalent of this existing dialog frame. Change ONLY the navy interior to uniform neutral #383838. Preserve the white border, rounded corners, transparency and original geometry. No new shapes, gradients, textures, shadows, text or highlights. The final production asset will reuse the original exact border/mask and use your interior material. Output PNG.

Asset tests compare alpha, stretch markers, white border pixels, and center fills
at every resolution. Dialog tests cover initialization, live changes, and preserving
an open dialog's content and focus. These SceneGraph tests require a device run
to verify runtime behavior; test compilation alone is insufficient.

## SquareButton

SquareButton reads and observes global.theme through Theme.SquareButton. Its
64px tile is images/themes/{blue,black,grey}/square-button-background.png. Blue
was moved unchanged; Black (#262626) and Grey (#4A4A4A) preserve its exact alpha
mask. These fixed-size tiles do not need resolution-specific variants.

Wider library-settings buttons keep the shared resolution-specific primary focus
nine-patch, tinted with the active theme's fill (Blue retains #092452). Returning
to square size restores the tile and removes the tint. The existing shared light
highlight remains in images/library/letter-tile-highlight.png. Selection retains
55% highlight opacity; focus remains fully opaque. Text is light when inactive,
and dark blue for active Blue, off-black for Black, or charcoal for Grey.
Theme updates preserve content, width, focus, selection, and button events.

Built-in image generation supplied the neutral fill samples, applied to the
original exact alpha mask. Black prompt:

> Use case: precise-object-edit. Edit target: existing 64px rounded square Roku button tile. Change only the navy fill to uniform neutral off-black #191919 for the Black theme. Preserve rounded square geometry and transparent corners. No border, shadow, gradient, texture, text, or additional shapes. Output PNG. Production will use the original exact alpha mask and sample your interior.

Grey prompt:

> Use case: precise-object-edit. Edit target: existing 64px rounded square Roku button tile. Change only the navy fill to uniform neutral dark grey #3D3D3D for the Grey theme. Preserve rounded square geometry and transparent corners. No border, shadow, gradient, texture, text, or additional shapes. Output PNG. Production will use the original exact alpha mask and sample your interior.

Asset tests check every alpha/fill pixel. Component tests cover initial themes,
live focus/selection preservation, wide/square transitions, HD rendering, and
fallback. Device tests remain necessary to verify SceneGraph runtime behavior.

### Unfocused button contrast adjustment

Black and Grey fills are slightly lighter than their dialog backgrounds so
unfocused buttons remain distinguishable: #262626 against #191919, and #4A4A4A
against #3D3D3D. Square assets and wide-button tints use the same target colors.
The original masks and focus/selection highlights remain unchanged.

Built-in imagegen adjustment prompt, once per theme (black/#262626 and grey/#4A4A4A):

> Use case: precise-object-edit. Edit this existing rounded square button PNG. Change only the interior fill to uniform neutral {color} for the {theme} theme. Preserve original shape and transparent corners. No other changes. Production will preserve the original exact alpha mask and enforce the requested exact fill color.

The generated previews were normalized to uniform exact target RGB values using
the original alpha masks. Final files remain
images/themes/{black,grey}/square-button-background.png.

## Live settings preview

SettingsContent emits themePreviewRequested only on selection. SettingsDialog
forwards it through OverlayHost's eventFields to MainScene, which uses syncTheme
to publish the preview without changing m.settings or writing registry data.
Normal close saves through the existing SettingsDialog path and fans out committed
settings. OverlayHost reports cancellation for Settings on programmatic removal,
so MainScene restores its canonical current settings, even if the header is hidden.
Restoration uses current session state rather than the dialog's opening snapshot;
login/reset/account changes therefore cannot restore a previous account's theme.
Returning to login cancels the active overlay without saving Settings edits,
then restores Blue. Theme-preview events are ignored while login is visible.

## Dialog image loading during preview

Dialog retains one Poster. It observes loadStatus and remembers only the last
successfully loaded panel URI. Before requesting another theme, it sets that
URI as both loadingBitmapUri and failedBitmapUri. Rapid selections therefore
keep a known-ready panel as the placeholder; loading/failed replacements never
become the fallback. A ready replacement becomes the next fallback. Reapplying
the current URI avoids another image assignment. Initial loading has no previously
ready panel to retain.

This uses Roku's documented [Poster loading placeholder](https://developer.roku.com/dev/docs/poster).
The existing nine-patch assets, theme folders, and dialog geometry stay unchanged.
Tests cover ready, loading, failed, initial, and unchanged-theme paths; eliminating
the visual flash and preserving nine-patch placeholder scaling still require an
on-device check, which has not been run.

## A?Z gutter launcher

The shared LetterGutterButton is text-only in vertical and horizontal layouts.
It has no background or separate focus fill, so it blends with every theme.
The light A?Z labels retain their colors when focused. Focus notifications and
selection keys still open the letter-grid dialog; the SquareButton tiles inside
that dialog are unchanged.

## Person page background

The person page biography and related movie/episode rows share MainScene's themed
background. The biography's solid navy panel is removed; the rows were already
transparent. Portrait, labels, buttons, spacing, and scrolling layouts are unchanged.

## Account badge

The optional top-left account badge follows global.theme through Header and
Theme.AccountBadge. Shared neutral artwork is tinted for each theme, retaining
the existing renderer-compatible circular crop. Its matte matches the nearby
background gradient instead of retaining blue corners. See [Account Badge](account-badge.md)
for the palette and compositing details.

## Up Next screen

TVEpisodeUpNextAutoPlay has no local background. MainScene's themed background
shows through, as the player is detached before Up Next opens and the previous
page remains hidden. Episode cards, countdown, focus, and autoplay behavior are
unchanged.

## Music player background

AudioPlayer has no solid navy background. MainScene's active theme shows through
beneath the existing 18%-opacity album-art backdrop and translucent black dimming
layer. Artwork, playback controls, and screensaver behavior are unchanged.

## Live TV and Filmography preview backgrounds

Live TV's program preview and Filmography's selected-title preview have no local
background Rectangle. Both show MainScene's active themed background. Filmography
continues to show or clear its preview artwork and text as selection changes,
without toggling a separate panel. Layout and navigation remain unchanged.

## Detailed media card background

Detailed library cards use a rounded 882×496 panel behind artwork and text, with
FHD and HD masks (882×496 and 588×331). Theme.DetailedCardBackgroundUri resolves
images/themes/{blue,black,grey}/detailed-card-panel.png. Blue retains #101C2A;
Black uses #262626 and Grey uses #4A4A4A. Cards observe the global theme so live
Settings previews update existing cards. Other card layouts keep the panel hidden.
Artwork masks, content positions, progress, watched badges, and focus highlights
are unchanged. generate-detailed-library-assets.ps1 generates the shared masks
and all three solid panel assets.

Detailed-card titles use `SmallBoldSystemFont`. Their top aligns with the poster at y=32. The title box is 64 pixels tall, with both metadata presentations starting at y=96 beneath it. The overview remains at y=142.

An experimental 2-pixel solid-white divider spans the detailed card's 516-pixel
text column at y=135, below the metadata row and above the overview.
