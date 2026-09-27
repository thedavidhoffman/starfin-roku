# Watched Indicator Style

Settings > Theme contains a Watched indicator section below the theme choices.
Its divider at y=239, heading at y=276, and options at y=324 match the Media shell
panel's spacing and styling. Up/Down moves between the two option lists; Left
returns to the category list.

- **Subtle** (default): original black badge with a white check mark, with its
  interior made fully opaque.
- **High contrast**: opaque progress-fill gold (#E2A44C) with a black check mark.

Both images are 58x58, retain smooth transparent outer corners, and use the same
existing component sizes and positions. Poster focus spacing is independent of
style. Unwatched items and media types that suppress watched badges stay unchanged.

The code key is SettingsStore.Key.WatchedIndicatorStyle and the registry key is
watched-indicator-style. Values are subtle and high-contrast, represented by
WatchedIndicator.Style. The setting lives in the existing per-account registry
section; absent or invalid values resolve to subtle. No migration is required.

SettingsContent emits watchedIndicatorPreviewRequested only after selection.
SettingsDialog forwards it through OverlayHost to MainScene. MainScene owns the
active global watchedIndicatorStyle; WatchedBadge observes it and chooses the
shared image for media cards, TV season cards, and episode posters. Existing
badges update without rebuilding library content.

Normal dialog close saves the account preference through the existing settings
flow. Cancellation restores the current session preference. Login/reset restores
Subtle, account loading applies that account's saved choice, and preview events
are ignored while login is visible. Theme previews do not change the badge style.
