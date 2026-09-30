# Settings cards

SettingsCard is a presentation-only Group used by every Settings category. It
owns the glass nine-patch background, uppercase SmallBoldSystemFont heading,
optional muted SmallestSystemFont description, and horizontal layout of direct
RadioButtonList children. It owns no focus, settings state or persistence.

## Layout contract

Pages supply title, cardHeight, controls and their vertical positions. headingY,
descriptionTop and descriptionHeight accommodate each page's measured spacing.
cardWidth defaults to 1040px for standalone use; SettingsContent supplies the
1160px width directly in initCardLayout and calls updateCard after all
content children exist. Subsequent cardWidth changes resize radio content too.

SettingsDialog assigns its fixed 1680 x 900px dimensions directly to the dialog fields.
SettingsCard owns the 24px content inset and 32px native radio focus
overhang as local values in updateCard. It computes radio x as inset + overhang, and item width as
cardWidth - 2 * (inset + overhang). At 1160px this yields x=56 and width=1048;
at 1040px it yields x=56 and width=928. XML supplies only vertical radio geometry;
its zero horizontal placeholders are resolved during SettingsContent initialization.
The heading and description use cardWidth - 2 * inset. The glass graphic is inset
3px and is 6px smaller than the card box. Custom buttons, inputs and the Libraries
table retain their page-owned layouts.

The background uses translucent header-nav-style glass with 12px FHD / 8px HD
corners. It has no focus-dependent outline. Native control highlights supply
focus feedback. The generator is scripts/generate-settings-card-assets.mjs.

## Page ownership

SettingsContent owns category navigation, controls, subtitle paging and the
language picker. SettingsNavigation names subtitle category, control and page
indices shared by its scripts. Subtitle pages use a short fade and a non-focusable
page number/chevron; there is no clipped scroll surface or scrollbar.

Libraries retains its existing table inside one titleless 1160 x 640px card.
The 1045px table is centered horizontally and inset 24px vertically, preserving
all eight rows and their controls. See [Settings presentation](settings-presentation.md)
for the retained experiment references and local preference behavior.

Component tests cover title/description rendering, hidden descriptions, radio
margin calculations and width changes. Runtime verification remains deferred
until wrap-up.
