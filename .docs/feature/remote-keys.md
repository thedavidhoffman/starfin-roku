# Remote Keys

`source/Remote.bs` defines the string-valued `Remote.Key` enum used by remote
input handlers and helpers that accept remote key input. It preserves the
existing values: `up`, `down`, `left`, `right`, `back`, `OK`, `select`, `play`,
`playpause`, `rewind`, `fastforward`, and `options`.

Handlers retain their existing press/release behavior, aliases, focus movement,
and event consumption for canonical input. Handlers compare input directly
against the enum without lowercasing. Confirmation uses `OK`; directional keys
and the supported `select` alias use lowercase. Noncanonical casing such as
`ok`, `Select`, or `BACK` is not normalized into a supported key.
The enum does not make all handlers accept every alias.

Text alignment, chevron directions, and playback seek-direction state remain
separate contracts even where they use the same strings. Tests keep literal
remote inputs to independently verify handler behavior, and `Remote.spec.bs`
checks each enum member against its literal value.
