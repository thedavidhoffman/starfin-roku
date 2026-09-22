# Account Badge

The optional `AccountBadge` control appears in the upper-left header when
enabled in Settings and an authenticated user identity is available. Header
provides the image URI, username, and palette colors. The control owns its
internal artwork geometry and compositing, while Header owns its placement in
the resolution-specific header layout.

## Resolution Behavior

The application uses a 1920x1080 SceneGraph coordinate space at every output
resolution. The account badge therefore always uses one logical scene geometry:
a normal 96x96 profile Poster visually cropped by an inverse-alpha corner matte,
surrounded by 102x102 ring and glass nodes. Roku scales that complete geometry
for a 1280x720 display.

Header keeps the reference badge position at `[48,16]` for 1080p. At 720p it
uses `[48,25]`, moving the badge down six physical pixels relative to its
default scaled position. This both clears the output edge and leaves a visible
top margin. The placement adjustment moves the complete badge without changing
its internal image, matte, ring, or glass alignment.

The username label is a sibling of `badgeVisual`, not one of its artwork
layers. Changes to artwork geometry, scaling, or compositing therefore do not
scale or reposition the username typography.

The control uses the same FHD scene geometry and FHD overlay assets at every
output resolution. Roku performs the only scale needed when it maps the scene to
a 720p display. The profile Poster is decoded at 192x192 before being displayed
in its 96x96 scene node, preserving detail through the final downscale.

## Circular Crop Compatibility

The badge does not use `MaskGroup`. Roku documents that `MaskGroup` is ignored
on players without OpenGL support, which exposes the square profile image on
affected devices. Instead, the control draws the profile Poster normally and
places a color-tinted corner matte above it. The matte is the inverse alpha of
the circular mask and covers the square corners with the header background
color. This preserves the circular crop on every SceneGraph renderer.

The visual layers are profile image, corner matte, ring overlay, and glass
overlay. The ring and glass overlays have transparent centers, so they can be
drawn above the matte without obscuring the profile image. All compatibility
assets are generated deterministically from the existing circular mask, ring,
and glass assets by `scripts/generate-account-badge-assets.ps1`.

The final geometry, circular crop, image sharpness, overlay composition, and top
margin have been visually confirmed on both 1280x720 and 1920x1080 displays.

Device automation changes the General setting through the production Settings
dialog, closes it, and verifies and captures the badge first visible and then
hidden on the authenticated application header.

## Theme colors

Header observes global.theme and applies Theme.AccountBadge on construction and
live theme changes, including Settings preview. The shared white matte/ring/glass
artwork remains under images/header; no per-theme duplicate bitmap is needed.
The inverse-alpha matte and the renderer-compatible Poster composition are preserved.

Blue retains its original palette. Black uses #0B0B0B for the matte, #121212 for
the ring, and #E8E8E8 for glass. Grey uses #2D2C2C, #343434, and #E8E8E8 respectively.
Matte colors are sampled from the corresponding images/themes background near the
badge's position, rather than from the dialog fill. This removes the blue corner
patches. Because the background is a gradient, these flat colors approximate the
local background. Identity, visibility preference, geometry, and username do not
change when a theme changes. Runtime appearance still needs device verification.
