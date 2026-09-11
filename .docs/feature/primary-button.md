# Primary Button

`PrimaryButton` keeps its caller-supplied dimensions and centers its icon and
text within them. Text width is measured with an unconstrained SceneGraph Label
using the displayed font through `source/TextMeasurement.bs`, shared with
DynamicButton. Each button retains its own measurement label. Text and font
changes recalculate the content layout.

Icon labels are constrained to the space remaining after the icon, gap, and
padding. Text that exceeds that space may truncate; the button does not expand
into neighboring controls. `getPreferredWidth` returns measured text width plus
the caller's horizontal padding for layouts that size text-only buttons.
