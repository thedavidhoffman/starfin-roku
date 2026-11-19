# DVD playback controls: agreed scope

This supersedes the earlier Previous/Next and title-timeline proposal. The backend
contract remains `starfin-dvd-session/1` and introduces transport version 1.
Previous/Next, three-second restart, automatic trailer skipping, custom chapter
selection, and the title timeline are deferred. Use authored DVD scene/chapter
menus. Arbitrary seeking and saved resume remain unsupported.

## Backend contract

A snapshot advertises `capabilities.transportVersion: 1`, `canPause`, and
`dvdMenu`. Previous, next, chapterSelection, and titleTimeline capabilities are
false. Missing capability fields mean unsupported. `canResume` refers to saved
resume, not unpausing.

`transport.canPause` and `transport.canRequestMenu` describe current availability:

| State | Pause/resume | DVD Menu |
| --- | --- | --- |
| playing / awaitingCompletion | With the current playback ID | Available |
| menu / still | Unavailable | Available |
| starting / preparingPlayback / stopped / failed | Unavailable | Unavailable |

Pause/resume POSTs carry a real requestId UUID, action (`pause` or `resume`), and
current playbackId. HTTP 200 returns a snapshot with authoritative `paused` state.
Actual paused-state changes increment revision; repeated pause with a new UUID
does not. The client must pause buffered video locally and reconcile rejection
with the returned/refreshed snapshot.

DVD Menu POSTs carry requestId, current revision, and action `menu`. Acceptance
returns starting state, a newer revision, paused false, null playback/menu, and
unavailable transport actions. The client stops old media and ignores old events.
The native engine clears its pending completion boundary and resumes navigation;
no separate resume is needed after a menu request from pause. Root Menu falls
back to Title Menu; authored video may play on the way. Availability is not a
promise that the DVD allows the action: native failure can fail the session.

Retries retain the same UUID and identical fields. Accepted duplicates return the
latest snapshot without re-execution. Replay storage retains 256 accepted commands;
UUID reuse with different fields returns 409 request-id-conflict. Stale playback,
stale revision, playback-not-ready, and navigation-not-ready return 409 without
performing the requested operation. Unsupported previous/next/selectChapter/seek
commands return 400 and are never forwarded to the VM.

Progress does not change revision or reposition the VM. Encoder title/chapter,
read-ahead elapsed time, and playlist duration are not viewer-relative title time.
The contract supplies no public timeline mapping or chapter-picker data.

## Starfin implementation

`DvdPlaybackControls` is a dedicated feature component with a centered Play/Pause button,
using PlayerToolbarButton, existing artwork/icons, and theme colors. It displays
metadata name/year with disc-label/top-level-year fallbacks, omitting absent year.
There is no timeline, previous/next button, chapter picker, or invented trailer
name. Standard PlaybackControls remains unchanged.

The component owns presentation and button focus and emits narrow action and
interaction events. DvdPlayer's local TransportControls helper owns availability,
local/server pause reconciliation, and the five-second visibility timer. Network
commands remain serialized through the existing session worker. Command results
carry their authoritative snapshot so rejection can restore pause even when the
revision did not change. Conflicting controls are disabled while commands run.
Local pause additionally waits for a playable/paused Roku Video state.

OK/direction reveals the hidden overlay without activating anything; initial
focus is Play/Pause when available, otherwise the overlay itself. Directional
presses keep focus on the single control. Remote Play toggles immediately; Options requests DVD Menu. Controls
hide after five idle seconds while playing and remain visible while paused or
buffering. Back first hides a visible overlay; during content playback or stills it then requests returnToLastMenu instead of exiting. Unavailable/busy requests do not turn into exits. Back from an authored menu or error exits. Plugin 0.1.27 restores its last interactive menu checkpoint. Options retains the separate Root/Title command. Authored DVD
menus hide the overlay, but Options remains available there when advertised.
Stills show metadata with Play/Pause disabled; Options remains the main-menu shortcut.

Accepted menu navigation releases the old Video before continuing. Each new
playback ID starts once, with looping/seeking disabled. Actual EOF alone sends
complete; awaitingCompletion does not. Session heartbeats continue every 30
seconds, including pause/stills. Exit deletes the session and stops client timers.
Authentication and server base paths remain unchanged. Library posters/selection
remain retained on return, and menu artwork never covers title/trailer playback.

## Status and verification

Backend source changes are based on 0.1.25; the handoff reports no newly published
package/version, deployment, or rescan requirement. Starfin controls depend on the
new capability fields; older responses leave the corresponding actions disabled.
This document records source implementation, not installed-server/device behavior.

No tests added/updated, builds, compilation, automated checks, deployment, or device
checks during this POC cycle. Source/diff review only. Pending authorized checks:
remote reveal/focus/Back, five-second hiding, missing name/year/capabilities,
pause/resume success and rejection, local buffering, menu from pause, menu failure,
stale snapshots/events, transitions and stills, actual EOF, heartbeat and cleanup,
authenticated HLS child requests, retained library focus, and 1080p/720p layout.

## Return to last menu (0.1.27)

Playback Back dismisses controls first, then sends `returnToLastMenu` with a new
request UUID and current revision. Gate it on both
`capabilities.returnToLastMenu` and `transport.canReturnToLastMenu`; missing/false
means unavailable. Do not require `hasMenuCheckpoint`: when false, the backend
performs Root/Title fallback. Busy/unavailable return never becomes an accidental
exit. Back from an authored menu/error retains the existing exit behavior.

Options still sends `menu`; there is no main-menu button in the overlay. Both navigation actions
share interruption bookkeeping, accepted-response cleanup, command serialization,
and stale-revision recovery. Accepted return releases the old Video, hides the
controls, and polls for the new snapshot. The normal menu renderer honors the
restored `selectedButton`. No old playback event may complete the new media.

The checkpoint is one menu per session, not a back stack. It survives playback
units/trailers/stills. It restores DVD registers, including audio/language, to
checkpoint values; later changes are rolled back. Menu animation may restart.
There is no saved resume or silent disc restart on fallback/native failure.

The backend reports 0.1.27 packaged but not deployed. Install the matching entire
`dvdnav` folder with the plugin; existing scan assets need no rescan. No deployment
or checks were performed by this Starfin change. Pending authorized device checks:
return from title, trailer, and pause; selected-button restoration; no-checkpoint
fallback; unsupported/busy gating; 409 refresh; late old-video events; preview
presentation; and the independent DVD main menu action.
