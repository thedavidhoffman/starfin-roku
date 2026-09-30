# Jellyfin account subtitle settings

Current user -> Subtitles shows Jellyfin account mode and preferred language on
page 1, followed by local per-account burn-in on page 2. Device -> Subtitles is removed.

The single-line account note sits above the mode card on page 1 in muted SmallestBoldSystemFont.
Glass cards below contain subtitle mode and preferred language, using uppercase
SmallBoldSystemFont headings. The mode description occupies one line with a blank
44px row before it. The language card has a compact Edit button and current value.

## Editing and saving on close

The first visit each Settings session loads /Users/Me and /Localization/Cultures.
Languages are sorted after Any language; regional and unknown existing values
are preserved. Any language writes an empty string. Unknown future modes remain
unchanged unless a supported mode is selected.
The language catalog is built once after loading and retains the original account
language throughout the session, allowing changes away from an unknown existing
value to be reversed.
Mode, language and save-status changes update selections without rebuilding the picker.

Mode/language choices update a pending snapshot without requests. Category changes
preserve edits; reverting both values to the loaded snapshot avoids a save.
The account notice reads "Saved to your Jellyfin account when you close Settings."
Back saves changed account preferences first, then local settings, and closes.
Closing with no account edits (including during initial loading) saves local
settings normally and cancels account loading.

A closing save uses the shared blocking Spinner with a two-second visual delay.
Focus and input blocking are immediate, but the spinner and scrim remain hidden
for fast requests. Success closes quietly. The delay timer is cancelled on every
completion or teardown; duplicate close and edit events cannot start another save.

Failure retains all edits and opens a separate SettingsSaveFailureDialog above
Settings through a dedicated top-level confirmation OverlayHost. It displays the
error in a scrollable area and Retry saving, Discard subtitle changes and close,
and Keep editing. Keep editing is initially focused and Back selects it. Retry
fetches fresh configuration again. Discard performs no account write but saves
local settings and closes. Keep editing restores the prior control/page. A timed-out
request may already have reached Jellyfin; Discard does not undo that server write.
Long errors can be scrolled by moving Up from Retry; Down at the end returns to Retry.

If an app message overlaps the save, acknowledging it returns focus to the still
pending save blocker or the failure confirmation that has since appeared. Existing
focus within that confirmation is preserved; otherwise Keep editing receives focus.

Confirmation decisions are correlated to the owning dialog and request. Account
changes and teardown dismiss the confirmation, stop owned blocking UI, and reject
obsolete task responses or decisions. They cannot undo an already received POST.

## Ownership and requests

SettingsDialog owns the original and pending account snapshots and its task
lifecycle through its component-local AccountSubtitleSession.bs helper. The main dialog
script retains opening, local persistence, previews/reset and the close path.
Both scripts share the dialog context and existing interface. SettingsContent owns
rendering, the picker, and focus through AccountSubtitleEditor.bs. Shared enums
and pure helpers remain in source/AccountSubtitles.bs. MainScene and
OverlayHost pass explicit server, token, and userId context; they do not perform
account configuration requests. AccountSubtitleTask has load/save commands and
correlates responses by request identity, server, and user. Each HTTP request has
a 15-second timeout.

SettingsDialog validates responses and releases the completed task before routing
to separate load/save completion handlers. deactivateAccountSession stops tasks,
releases blocking/confirmation UI and clears the editor session.
Repeated deactivation does nothing; successful saves release the blocker through
final closure, while failed saves release it before opening confirmation.
SettingsContent captures and restores editor focus for Keep editing, refreshing the mode description
for the restored highlighted option; deactivation clears the captured target.
Settings controls stay mounted during saving and the failure confirmation, so the
captured control is restored directly. With no saved target, focus returns to the
current category list.

Within AccountSubtitleTask, executeRequest validates and dispatches commands and
attaches response correlation. loadAccountSubtitles coordinates loadAccountConfiguration
and loadCultures, returning one complete editor result. saveAccountSubtitles uses
loadAccountConfiguration for its fresh read before merging and posting. HTTP requests
and response validation remain inside the task; the dialog does not aggregate them.

Save fetches fresh `/Users/Me`, verifies the user identity, merges only edited
SubtitleMode/SubtitleLanguagePreference fields into Configuration, and posts the
complete object to `/Users/Configuration`. HTTP 204 is success. Json.Serialize
serializes nested values with their original field spelling, retaining unrelated
and unknown configuration fields without FormatJson. The fresh read reduces
overwrites but cannot prevent another client's simultaneous full-object update.

Account preferences are never persisted in SettingsStore or the Roku registry.
Automatic playback continues to consume Jellyfin's DefaultSubtitleStreamIndex.
Saving preferences does not restart playback or change an explicit track choice.
SDH preference, audio preferences, and reporting per-title selections are outside
this feature.


## Verification during iteration

Component tests cover pending edits, save-on-close, failure decisions, stale results,
focus restoration, and local persistence. Account automation verifies that edits do
not reach Jellyfin before close, reloads saved values, and restores original account
preferences. Burn-in automation asserts per-account registry persistence.
Subtitle automation scopes control lookups to SettingsContent to stay within RTA's
node-search depth limit and uses its dedicated isInFocusChain API for focus checks.
The shared Settings helper reads account-session fields individually to preserve
field casing and waits for Home readiness before navigating the System menu.

The account note aligns with the cards at x=3. The account spinner uses its
standard two-second visual delay, preventing a dark-overlay flash on fast loads
while the account page loads. Closing saves use the separate full-screen blocker.

## Subtitle pages

SettingsCard owns the glass background, heading, padding and description. Page 1
contains the one-line Jellyfin notice, mode and language. Page 2 contains
burn-in in a 384px card with a 120px description area. The category list stays fixed.
A non-focusable bottom-right indicator shows 1 / 2 with a down chevron on page 1,
and 2 / 2 with an up chevron on page 2. Down from the language Edit button opens
page 2 at the first burn-in option; Up from that option returns to Edit on page 1. Pages switch with a brief fade,
not scrolling. The language picker returns to page 1 and restores Edit focus.
The picker uses a SettingsCard with an uppercase heading, ten visible scrolling
language rows, balanced native-focus margins, and selection/Back guidance below.
Before the page number, a static, non-focusable "Additional settings" label uses
the same muted SmallestSystemFont on both pages, regardless of focused option.
The language picker hides the label with the rest of the editor. Page numbers,
chevrons and navigation are unchanged.
While account data loads or Retry has focus, Down opens burn-in on page 2.
Up from the first burn-in option returns to the loading control or Retry on page 1.
Retry keeps focus on page 1 while loading. Completion focuses the account controls
or Retry if that page still owns focus; returning to local burn-in does not cause
a later response to steal focus. Mode descriptions follow the focused mode while
its list owns focus and the selected mode otherwise, including pending selections.
Burn-in saves locally on close; mode/language save to Jellyfin before closure.

## Burn-in registry cleanup

Subtitle burn-in is stored per account, not per device. The legacy device value
is ignored and is not copied to accounts. Accounts without a saved burn-in value
use During transcoding; existing account values are preserved.
SettingsStore.Save deletes only the obsolete device subtitle-burn-in-mode key
alongside its normal global writes and flush. Loading settings performs no cleanup
or migration. The legacy key may remain harmlessly until settings are saved.
Playback consumes the active account settings and needs no selection change.
