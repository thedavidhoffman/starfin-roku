# Video Toolbar

VideoToolbar owns button order, focus, and spacing. Ordinary buttons expand only while focused; otherwise they remain 64 pixels
wide. Buttons have a 12-pixel gap. The final media-options button has a cog icon and
retains its measured width and visible label regardless of focus.

DynamicButton lives in `components/controls/Buttons/DynamicButton/` and uses
`source/TextMeasurement.bs`, shared with PrimaryButton, to measure its text with
an unattached, unconstrained SceneGraph Label. Each button retains its own
measurement label using the visible label's font. Its `preferredWidth` includes the
icon area, text, and padding. The configured `expandedWidth` is a minimum, so
labels such as `Resume S3:E20` and longer episode numbers can grow to fit.

Text and minimum-width changes update the preferred width and button visuals.
VideoToolbar observes preferred-width changes and repositions neighboring
buttons without changing focus. Shorter labels shrink back toward the configured
minimum; losing focus restores the compact icon-only appearance.

## Button appearance

DynamicButton uses fully rounded pill ends, matching the player toolbar's shape.
The unfocused fill remains blue-grey (`#182130`, alpha 210/255); focus uses solid
white with dark icons and text. The existing 58-pixel height, 64-pixel collapsed
width, expansion, and persistent-summary behavior are unchanged. Focused buttons
center the icon and measured text together with their existing 12-pixel gap and
equal outer insets, then apply a 1-pixel left optical adjustment to the focused
icon/text group. Button widths stay fixed by the existing measurement rules;
text is constrained to the available space when a width cap applies. Losing focus
restores the existing unfocused placement.
`scripts/generate-dynamic-button-assets.mjs` generates the two nine-patch backgrounds
with fixed rounded ends and a stretchable center.

## Media summary

Movies and episodes show media info last in visual and remote navigation order.
The cog-and-summary button opens the shared [Media Options](media-options.md) dialog
and retains focus when that dialog closes. Its label follows this format:

`[resolution] [video codec] [HDR type] • [audio codec] [channel layout]`

Examples: `1080p H.264 • AC3 5.1`, `4K HEVC HDR10 • EAC3 5.1`, and
`4K HEVC Dolby Vision • TrueHD 7.1`. Container, bitrate, frame rate, and size
remain in the detailed view. The summary describes source media, not a negotiated
transcoding output. No additional API requests are made.

`source/VideoMediaSummary.bs` owns pure formatting and stream selection. It uses
the first media source's nonempty streams, falling back to item-level streams.
The first non-artwork video stream supplies video information. Audio follows the
page's explicit selection, then the default audio stream, then the first audio
stream. Missing selections fall back to the default. Movie and TVEpisode own
refreshing `VideoToolbar.mediaInfoText` on rendering, selection, and reset.

Resolution tiers use width or height thresholds (7680/4320, 3840/2160,
2560/1440, 1920/1080, 1280/720), preserving familiar labels for cropped films.
Smaller dimensions display SD. Interlaced HD uses an `i` suffix. Known codec
aliases are normalized; unknown identifiers are uppercased. Explicit HDR types
are shown, with Dolby Vision preferred over its HDR compatibility format;
SDR is omitted. Explicit channel layouts take precedence, with mono/stereo
normalized to 1.0/2.0. Without a layout, 1/2/6/8 channels become 1.0/2.0/5.1/7.1;
other positive counts use `Nch`. Missing data and empty separators are omitted;
no useful metadata displays `Media Info`.

DynamicButton opts into persistent text through `alwaysShowText` (default false).
Empty icons remove the icon area and center the label within equal horizontal
insets. This balances the spare measurement width without resizing the button;
icon-and-text buttons retain left-aligned labels. `maxWidth` defaults to unlimited; media info
sets it to 640 pixels, with single-line label ellipsis for overflow. Focus changes
background/text colors, not the summary button's width. Existing buttons retain
their normal expansion behavior.

## Initial metadata loading

An empty `mediaInfoText` keeps media info hidden and out of toolbar navigation.
Movie and TVEpisode clear the label when a new title starts loading and hold it
empty until the current details request completes. Initial cached content and
stale responses cannot reveal a placeholder or a previous title's summary.
The page then supplies the final summary, or `Media Info` when details completed
without usable stream metadata (including a failed load with no stream data).
The toolbar updates text and measured width before revealing the button and
preserves the currently focused action when the summary becomes available.
Same-title background refreshes retain the existing summary while loading.
