# Video Media Information

The movie and episode toolbar opens Media Information in the standard Dialog frame, matching System Information. Gold section headers and label/value rows replace the full-screen horizontal stream-card carousel.

Sections appear in source, video, audio, then subtitle order. Each stream gets a numbered section with its display title or a metadata summary. Source information includes the media title, container, file size, and path. The redundant source-name row is omitted. Stream rows retain resolution, frame rate, codec, profile, video range, bitrate, channel layout, language, and stream flags where available. Missing fields are omitted; unavailable source, stream, and subtitle information has explicit empty states. Long values wrap and expand their rows. Media information uses a 260-pixel label column and a 768-pixel value column, separated by 24 pixels. The centered media dialog is 1,200 pixels wide and 940 pixels tall. System Information retains its 1,536-pixel dialog and wider 530-pixel label column.

Up/Down scrolls the property sheet; holding either key repeats scrolling. The scrollbar indicates position. Back or OK closes the overlay and restores focus to the media-info toolbar button. This is a read-only view of the first source, falling back to item-level streams when the source stream field is absent. It does not select tracks, request metadata, or change playback.

`VideoMediaInfoDialog` extends `Dialog` and wires the item to `VideoMediaInfoContent`. Movie and TVEpisode use the existing `mediaInfo` OverlayHost request and close route. `VideoMediaInfoContent` owns media formatting. The shared `SectionedInformation` control owns section rendering, wrapping, scrolling, and scroll timers; SystemInformationContent uses it too and retains ownership of system-data collection. Updating sections resets scrolling and stops held-key timers.

Rooibos suites cover data formatting, dialog lifecycle, rendering, scrolling, empty states, and the toolbar close/focus path. No new RTA automation suite is added.
