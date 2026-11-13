# Startup Account Selection and Multi-Server Switching

## Device preference

Settings > General contains two equal-width cards: **Select account at startup**
on the left and **Account badge** on the right. The TMDB API key remains below.
The startup preference defaults to Off, saves with the existing settings close
flow, applies to every account on this Roku, and takes effect on the next launch.
It uses the global `select-account-at-startup` registry key with `off`/`on` values.
Absent preference values use Off. Account identity migration is described below.

With the preference Off, startup resumes the saved active account as before.
With it On:

- Two or more signed-in accounts open the full-screen selector before account
  authorization, Home activation, or Home data requests.
- One signed-in account is authorized directly, even if a different account was
  previously active. Failure opens Login; it never leaves a blank startup screen.
- No signed-in accounts open Login.

A signed-in account is a saved account with server, user identity, and a token.
Tokens are checked against the server only when selected; no startup probes are
sent to every server. An expired token can therefore initially appear in the list.

## Shared presentation

`AccountPickerContent` is used by `AccountPickerPage` and `AccountPickerDialog`.
The header switcher and Login's saved-account dialog both show signed-in accounts
across all saved servers. AuthController supplies view models without tokens.

For accounts on one normalized server address, the picker retains its horizontal
avatars, usernames, active indicator and forget hint, without a server label.
The startup page shows up to five horizontal accounts; the dialog shows up to
three. All visible account groups, including a full five-account startup row,
are centered using their visible avatar/label bounds, excluding extra
focus-canvas padding. Longer lists retain this centering while scrolling
with chevrons calculated from the host capacity. Removal confirmation keeps its
avatar beside the explanatory text rather than using picker centering.
For multiple servers, it displays a vertical scrolling list with a 96-pixel avatar,
username, saved server address, and active/forget status. The row reuses the
trailer dialog's rounded highlight artwork with light text. Its avatar uses the
same resolution-aware circular cast mask as the horizontal picker. The status
is an explicitly declared `accountStatus` ContentNode field, rendered at 20px. Addresses can be hostnames
or IP addresses including scheme, port and path. They are single-line ellipsized
labels of fixed width; they do not enlarge rows or displace avatars. No server-name
lookup or alias merging is performed.

The list-mode dialog is 760px wide: 640px rows plus the standard 60px margins
on each side. Horizontal mode retains its 920px dialog. Forget confirmation fits
inside the current width; removing the last other-server account restores the
horizontal width.

Vertical rows are capped at 640px and centered in the shared content area, with
text widths derived from that row width. The full-screen content area is 800px
wide in vertical mode and 1280px in horizontal mode, centered below a text-only crop of the Login logo, displayed at 650x166.
The separate `images/logo-startup-wordmark.png` preserves the original lettering
pixels and transparency while excluding the yellow mascot. The original Login
asset is unchanged. Branding
belongs to AccountPickerPage only; AccountPickerDialog has no logo. There is no
redundant Select account heading. The logo, 72px gap, accounts and footer form
one group centered at y=500, slightly above the screen center. A minimum 60px
top margin keeps five-row lists on-screen. Changes in content height rebalance
the whole group. The startup page requests 40px before the sign-in button;
the dialog and forget confirmation retain their compact 24px footer gap.
Server addresses use 26px text to keep usernames visually prominent.

The dialog shows up to three vertical rows; the full-screen page shows up to five.
Short lists use only the rows present. Shared content owns footer placement and
publishes `preferredHeight`; the dialog uses its existing `fitContentHeight`
interface to size and center the frame. A two-account vertical dialog is 558px
high, a capped three-row dialog is 686px, and the horizontal picker is 574px.
The forget confirmation uses a centered 640px body with a single avatar, 30px
gap, and 403px description, independently of the account list's width or capacity.
The description wraps at its natural height without a fixed-height or line cap.
Confirmation body height is the greater of the avatar/name's 237px height and
the measured text height, with shorter text vertically centered beside the avatar.
Buttons stay centered 24px below the body; the shared preferred height includes
them so the startup group and dialog grow together when needed (minimum 547px
dialog height). This
keeps both horizontal and vertical startup confirmations compact. Cancel, Back,
and successful removal recompute
the picker layout and restore its appropriate height without changing focus flow.
Both keep
**Sign in with another account** below the list. Native list navigation handles
scrolling; Down from the last account reaches sign-in and Up returns to the saved
account focus. Active accounts are listed first, with existing server/name sorting
for the remainder. Initial focus prefers the active account in the dialog and the
last-used account at startup; startup does not authenticate or clear that saved
reference merely by showing the picker.

The vertical list handles Options directly and emits the focused account through
an always-notifying `forgetRequested` event. Shared content owns the existing
forget confirmation, removal, cancellation, and return focus. In the dialog,
inactive rows show `* to forget`; the authenticated account shows `Active` and
cannot be forgotten. Startup has no authenticated account: every row shows
`* to forget`, including the last-used account. The full-screen host disables
`protectActiveAccount` on the shared content; the dialog retains its default
protection. Cancelling confirmation preserves both the account and its saved
active reference. Confirmed startup removal clears that reference only when the
removed account was last used, after successful registry deletion and flush.
`AuthStore.ForgetAccount` retains its default active-account protection for other
callers and requires explicit opt-in for startup removal.
Removing an account recomputes the layout and restores focus to a remaining
account at the removed position, falling back to the preceding account when the
last account is removed. Reducing an already-open selector to one account does not auto-sign-in.

## Startup lifecycle and ownership

MainScene owns a grouped startup state (active, busy, page) and gates startup
before requesting authorization. The page is attached to the XML-declared `startupAccountHost`, above the app
background and below Login and shell overlays. Its layering does not depend on
a numeric child index in Scene. Startup logs record page creation and the final
account count/focus state to distinguish construction failures from visibility issues. It has no independent authentication state.
The shared content owns rendering, layout, focus, selection and forgetting.
It publishes `verticalLayout` so containers use the same presentation decision.
Geometry updates preserve list content and focused account identity. Only the
active list is built; forget confirmation has its own preview. Cancelling
confirmation restores the existing list without rebuilding it.
AuthController owns authentication, token expiry and committing active accounts.

Selecting an account starts blocking progress and authorizes against that
account's saved server. Duplicate startup selections are ignored while busy.
Only successful authorization commits the active account. MainScene then removes
the startup page and uses the existing session path to load settings, identity,
permissions and Home data. Cross-server switches use existing dynamic-page,
playback and theme-audio cleanup; Home resets its session-bound refresh state
when it receives the new load request.

Connection failures during startup selection restore the selector and show the
shared acknowledgment message; no other account is selected automatically.
Dialog selection failures reopen the originating picker with refreshed accounts
and focus the failed account before showing the acknowledgment. Header failures
restore the outgoing account's Home behind the picker so cancelling it remains usable. MainScene retains
this pending selection context until success, failure, or expiry; the active
session remains unchanged on connection failure.
Expired tokens are removed through AuthController's existing path, and Login is
prefilled with the selected server and username. Failed additional sign-ins stay
in Login. Both password login and Quick Connect can complete startup.

Back on the startup selector exits the app without resuming an account. Back from
its Login flow returns to the selector and refreshes eligible accounts, after
nested keyboards, Quick Connect and discovery UI handle their own Back actions.

Launch deep links remain pending while selection/authentication is incomplete.
The initial selection does not cancel them; they resolve against the authenticated
account's server. An unavailable item follows the existing Home fallback. Later
account switches retain their existing deep-link cancellation behavior. Launch
completion remains tied to the final destination's readiness, not picker display.

## Coverage and verification

Functional coverage includes account enumeration/token omission, global preference
persistence, paired settings navigation, adaptive layouts and row geometry,
selection/forgetting/focus, startup account counts, duplicate selections, failures,
expiry routing, Back, successful session adoption, and pending deep links.

The implementation was reviewed at source level. Automated validation, builds,
Rooibos device tests and UI automation are deferred until explicitly authorized.
Device verification must exercise both layouts at HD/FHD, long addresses, lists
longer than the viewport, nested sign-in cancellation, authentication failures,
and cross-server switching without prior-session content appearing.

## Account identity migration

Account keys use `v2/<encoded-server-identity>/<encoded-user-id>`. The shared
`Url.ServerIdentity` helper normalizes scheme and hostname casing and trailing
slashes, preserving ports, schemes, and case-sensitive paths as distinct server
identities. Picker layout uses the same helper; no server alias discovery occurs.

Before loading the saved session, AuthController asks AuthStore to migrate legacy
account sections using their stored server and user ID. The complete section is
copied, including tokens, account settings and library view state. Destination
values win on retries; missing values are copied. The destination is flushed
before updating the active reference, and legacy data is deleted only after those
writes succeed. Incomplete migrations retain legacy records for the next launch.
This changes local storage only and cannot recover records overwritten by an old
account-key collision.

## Automated regression workflows

`tests/automation/specs/account-selection.spec.mjs` exercises the real startup gate,
authorization tasks, picker controls and routing with an HTTP fixture reachable
from the Roku. Two distinct server base paths share the same user ID, so switches
also exercise the versioned account identity. The fixture records requests and
can hold authorization/Home responses or return 401/503 responses.

Scenarios cover zero/one/multiple accounts, preference persistence across launch,
no Home requests before successful selection, duplicate keys during authorization,
horizontal and vertical scrolling, long addresses, active-account protection,
forget/cancel, keyboard/discovery/Quick Connect cancellation, password sign-in,
Quick Connect completion, expiry and refreshed eligibility, failure recovery,
startup Back exit, deferred deep-link resolution to Home fallback, legacy record
migration, and cross-server settings/context adoption with delayed old responses.
Each case snapshots and restores Starfin registry sections. Screenshots are taken
by the tests for overflow/long-address evidence; visual correctness still needs
inspection when device verification is authorized. The suite uses the existing
HD/FHD automation runner rather than adding a separate resolution mechanism.

Automation startup helpers recognize the picker as a valid waiting surface.
Authentication helpers enter Login with configured test credentials instead of
silently selecting an arbitrary saved account. Node tests cover these helpers and
the HTTP fixture itself.

Rooibos additionally exercises destination write/flush failures, retry ordering,
inactive-account migration and idempotence. `bsconfig-test.json` enables a small
AuthStore factory substitution only in emitted test code, allowing deterministic
native-registry failures without filling the device registry. The factory is
appended to the AuthStore test script so it is available in each importing
component scope. Production source, production builds and automation builds do
not include this substitution. Normal tests delegate to the real native factory
unless a registry fixture is explicitly installed, and teardown clears it.

Focused verification was authorized and run on November 13, 2026:

- All 20 selected Node tests passed.
- The 15 affected Rooibos suites exercised 967 cases. After correcting test
  fixtures and expectations, the run had 960 passes and seven failures; a final
  rerun of the three corrected suites passed all 335 cases, including those seven.
- The account-selection E2E suite passed 23 of 24 cases. The remaining forget
  case passed on a targeted rerun after adding a wait for inactive-account focus
  before pressing Info.

Corrections were confined to tests: the MainScene harness now includes the
startup host, SceneGraph numeric expectations use the correct field types,
settings/discovery expectations reflect the new behavior, and overlay assertions
exclude Rooibos-owned children. No production fixes were required by these runs.
The full test suite, separate final validation checks, and manual visual review
were not run as part of this focused verification.

After the horizontal centering, startup last-used-account, compact confirmation,
and measured text-height changes, a second focused verification on November 13
passed all 131 picker/account-store unit cases and both horizontal-scrolling E2E
cases (startup and dialog). Unit coverage includes longer confirmation text,
footer clearance, propagated height, cancellation, and last-used-account removal.
The new last-used-account E2E cases were outside this two-case E2E rerun.

Function-header validation passed for 3,678 functions in 374 files. Tracked diffs
and all 19 untracked text files had no whitespace diagnostics. The full suite and
manual visual review were not included in this final focused run.
