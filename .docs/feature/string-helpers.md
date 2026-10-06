# String Helpers

`source/String.bs` owns string conversion, joining, trimming, whitespace
normalization, natural comparison, markup removal, replacement, and digit
recognition.

## Pure conversion

`Strings.ToString(value, fallback = "")` returns strings unchanged, including
empty strings. Intrinsic and boxed booleans become lowercase `true` or `false`.
Other values supporting `ToStr` use that method, preserving existing numeric
formatting without the sign-placeholder space introduced by `str`.

Missing (`invalid`) and unsupported values return the supplied fallback. Arrays,
associative arrays, and unsupported SceneGraph nodes are not interpreted as text.
Conversion has no logging, registry, or SceneGraph state side effects. Logger
uses this shared conversion; String does not depend on Logger or Format.

`Join`, `Trim`, `CollapseWhitespace`, `StripHtmlMarkup`, `NaturalCompare`, and
`GetJoinedText` use the same conversion with empty fallback text. `Join` preserves
whitespace and array positions, including empty positions; non-array inputs
retain their empty-result behavior. `GetJoinedText` trims entries and omits empty
ones, preserving its existing associative-array key iteration. `Trim` removes
surrounding spaces only. Natural comparison treats unsupported inputs as empty
text and retains numeric-run ordering.

Conversion does not validate URLs or identifiers; callers still own domain
validation. Format retains its other functions and imports String; its
`FirstNonEmpty` and `WithCommas` behavior is unchanged.

## Boundaries and coverage

`Replace` returns the source unchanged for an empty search string. Empty
replacement text still removes matches. `IsDigit` accepts exactly one ASCII
digit, rejecting empty and multi-character strings.

Regression coverage exercises intrinsic and boxed strings, booleans and numeric
types, default/custom fallbacks, missing and unsupported values, mixed-array
joining, whitespace, natural sorting, Logger formatting, and replacement/digit
boundaries. MusicLibrary tests cover artist-object names and fallback rendering
on initial and appended album pages.
