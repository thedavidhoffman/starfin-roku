# Message dialog

AppMessage.Show(message) queues a nonblank acknowledgment message through MainScene.
AppMessage.Dismiss() cancels deferred/visible messages without restoring outgoing
page focus. User OK and Back share the dialog close path and restore a still-valid
previous focus target, then fall back to the underlying overlay or active surface.
The originating page continues to own request errors and recovery; no new requests
or persistence are introduced.

MessageDialog extends Dialog and mounts MessageContent. It uses the common frame,
backdrop, and Message title at 800 x 420 in 1080-coordinate space. The left-aligned
multiline label grows the panel up to 720 pixels high. Overflow scrolls with Up/Down
without moving focus off OK. The button sits 60 pixels from the bottom/right edges
and uses PrimaryButton.getPreferredWidth(30). Text is never ellipsized or shortened.

A dedicated messageOverlayHost above the feature host and spinner preserves
underlying dialogs and unsaved state. MainScene retains one return-focus reference,
defers opening until the current event finishes, protects modal focus, and merges
additional distinct messages into the same dialog. Dismissal/navigation cancels
the timer, removes the dialog, clears its close-event payload, and releases references.
Successful background responses no longer clear acknowledgment messages.
Focus recovery observes MainScene's focusedChild and runs through the same deferred
timer as opening. It does not call setFocus during a competing focus-change callback,
which can leave Roku's focus chain inconsistent for subsequent Back events.

Home collects messages within its refresh object, waits for core and Recently Added
requests to complete, and sends one combined message. Its existing readiness timing,
stale-response rejection, and silent On Now 403 exception are retained. New refreshes
discard old collected messages. Auth/account navigation clears the message layer.

Switching-account prose is removed; its existing spinner remains. Live TV uses its
existing preview labels for an empty channel list. Login-form feedback, inline artist
metadata failures, player-engine handling, and silent optional failures stay unchanged.
Localization remains parked.

Tests cover geometry, full multiline text, scroll boundaries, button focus, OK/Back,
deferred presentation, deduplication, underlying-overlay preservation, return focus,
focus theft, canceled navigation, Home aggregation, and existing error behavior.
Device runs preserve/restore the registry and restore the normal build afterward.

## Verification (2026-09-17)

- Production validation and explicit test build passed.
- Full current Rooibos suite: 2,957 passed, 0 failed, 0 crashed; detailed report checked.
  The review configuration excludes the pre-existing ignored localization
  LogDialog.spec.bs from the parked work, and uses explicit BrighterScript/BrightScript
  helper mappings to avoid an intermittent mixed-extension glob build failure.
- Roku 1080p checks passed for short, multiline, combined, and oversized messages,
  OK/Back dismissal, scrolling with OK focused, duplicate suppression, background
  focus recovery, and preservation of unsaved Settings values and return focus.
- Existing Playlist/TVSeason fixture problems that hid tests were repaired; MainScene
  tests now restore the controller fixture between cases. No production behavior was
  changed for those fixture repairs.
- Screenshots and the detailed review are under out/message-dialog-review/.

Original device registry restored and verified; normal workspace build redeployed
and launched at 1080p after testing.

## Review follow-up

MainScene routes Home hiding through hideHome(), which suppresses messages for
Home's outgoing refresh. Page/session cleanup does the same before account changes.
Home clears collected messages and ignores later failures for presentation while
allowing row loading to finish. A new refresh resets suppression; returning to the
same refresh does not revive its discarded messages. Ordinary overlays do not
suppress Home messages.

MessageContent retains its scroll offset as messages append, clamps it when content
shrinks, and starts at zero for each new dialog. Named layout measurements derive
reserved space, button placement, text width, and scrollbar placement from the
existing Dialog content geometry and button dimensions. Visual dimensions remain
unchanged. Overflow tests exercise the actual bottom and top of long content.

Review follow-up validation (2026-09-17): production validation and explicit test
build passed; Rooibos passed 2,965 tests with no failures or crashes. Device checks
confirmed append-position preservation, actual top/bottom overflow boundaries,
late Home failures suppressed over Search, and current failures displayed on a new
refresh. Evidence is under out/message-review-fixes/.

Original Roku registry restored and verified; normal workspace build redeployed
and launched at 1080p after the review checks.

## Standard test command follow-up (2026-09-17)

The normal test configuration initially failed compilation because an ignored
LogDialog test still referenced the parked Localization namespace. The obsolete
locale-change case was preserved under out/unit-test-repair/ and removed from
active discovery; all four current LogDialog behavior tests remain. Git now
includes both Logs component suites. The standard npm test command on the
configured Roku passed 2,969 tests, with zero failures, crashes, or ignored tests,
without the earlier review-only exclusion. No production changes were needed.
