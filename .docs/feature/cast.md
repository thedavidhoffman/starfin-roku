# Cast Display

The shared Cast component displays people on detail pages and during video
playback. Each card shows a person name and character/role text beneath the image.

Both text lines use native SceneGraph ScrollingLabel nodes with a maximum width
of 207 pixels. Each line scrolls independently only when its text exceeds that
width and the person is highlighted. Text that fits stays centered and still.

CastItem observes the RowList-provided itemHasFocus field after its node
references are initialized, and applies the current focus state on startup.
Focused labels use repeatCount -1 to repeat scrolling at 100 pixels per second;
unfocused labels use repeatCount 0 to remain ellipsized. Moving between people or
leaving the cast row disables scrolling for the previously focused item. Returning
focus enables scrolling again. Text updates continue through itemContent.

The native labels own overflow detection and animation. CastItem owns enabling
scrolling for both lines; parent pages require no additional scrolling state.

Functional coverage lives in the CastItem Rooibos suite. Device verification
should cover short and overflowing text independently on both lines, movement
between people, exiting the cast row, and returning from person details, on both
detail pages and playback. Run verification only when the development-cycle gate
authorizes it.
