# Video Toolbar

VideoToolbar owns button order, focus, and spacing. Only the focused button
expands to show its label; other buttons remain 64 pixels wide with a 12-pixel
gap between buttons.

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
