# Sending application logs to Jellyfin

The Application Log dialog has a bottom-right **Send Log to Jellyfin** button.
Right moves from the log to Send; Down at the end of the log also moves to Send.
Left or Up returns to the log. Moving focus stops held scrolling. The dialog
retains its scroll position while confirmation and acknowledgment dialogs appear.

Returning to the log explicitly releases the Send button's actual focus before
focusing the content root. Focusing an ancestor alone can retain the focused
button while removing its highlight. Left/Up must restore scrolling, remove Send
from the focus chain, and leave OK unable to activate Send until it is focused again.

## Snapshot and availability

Opening the dialog captures `LogService.getSnapshot()` once. Uploads contain all
stored entries from that snapshot, joined with newline characters, including full
URLs and multiline details. Display wrapping, URL shortening, and visual detail
limits do not affect the uploaded document. Entries collected afterward require
closing and reopening the dialog. Existing LogService retention limits still apply.

With an authenticated session, a background `GET /System/Configuration` reads only
`AllowClientLogUpload`. The task returns enabled, disabled, or unknown and never
publishes the configuration body. Selecting Send while the check is pending shows
a checking message. A false boolean shows an administrator-disabled message; the
button remains visible. Missing, nonboolean, or failed configuration reads leave
availability unknown and allow an explicit upload attempt. The app never changes
server configuration.

## Consent and delivery

Selecting Send opens a separate confirmation above the preserved log dialog. It
explains the destination, troubleshooting purpose, and that logs may contain server
addresses, media titles, and recent app activity visible to the server administrator.
Cancel is initially focused. Cancel and Back return to Send without uploading.

Send Log closes confirmation and starts a blocking, noncancelable spinner, with a
two-second visual delay. The dialog owns one upload at a time. The task sends an
authenticated `POST /ClientLog/Document` with Jellyfin client metadata and
`Content-Type: text/plain; charset=utf-8`. Invalid snapshots and snapshots with zero
entries are rejected before joining. `Arrays.IsArray()` checks for Roku's `ifArray`
interface without validating element types. Entry contents are preserved without whitespace
validation. Documents exceeding 1,000,000 UTF-8 bytes are rejected without trimming
or sending. There are no
automatic retries. The request timeout is 30 seconds; capability checks use 15 seconds.

Success opens an acknowledgment containing Jellyfin's `FileName`. A successful
response without a filename explicitly says the log was accepted without one.
Failures explain expired authentication, disabled uploads, unsupported endpoints,
size rejection, or connectivity problems. A timeout warns that the log may already
have arrived and suggests checking the server before sending again. Acknowledging
returns focus to Send. Server rejection remains authoritative even after an enabled
capability check.

## Dialog titles

| Situation | Title |
| --- | --- |
| Log viewer | Application Log |
| Consent | Send Log to Jellyfin? |
| Accepted upload, with or without a returned filename | Log Sent to Jellyfin |
| Capability check pending | Checking Log Upload Availability |
| Disabled capability or HTTP 403 | Log Uploads Disabled |
| Missing session or HTTP 401 | Sign In Required |
| Empty snapshot | No Log Entries to Send |
| Local size rejection or HTTP 413 | Log Too Large to Send |
| HTTP 404 or 405 | Log Upload Not Supported |
| Timeout with uncertain delivery | Log Upload Status Unknown |
| Other upload failure | Unable to Send Log |

The message body retains the filename, explanation, or recovery steps. The missing
filename success variant is defensive handling for an unexpected response, not an
expected Jellyfin response. Titles travel through the shared optional AppMessage
title parameter; unrelated combined messages use the generic "Message" title.

## Ownership and lifecycle

`LogDialog` owns the snapshot, availability, upload phase, correlated requests,
cleanup, and acknowledgments through `AppMessage`. `ClientLogUploadTask` owns HTTP
work and returns only capability or upload results. `LogContent` owns rendering,
scrolling, and the Send button. The confirmation dialog/content pair owns consent UI.

MainScene's shared confirmation host routes correlated results to the still-active
feature owner; it continues to support Settings save failures. Replacing or closing
the log stops its tasks and scrolling, invalidates responses, releases the snapshot,
and removes its confirmation. Session context is explicit request data. No plugin
or server-side installation is needed.

`HttpClient` respects an explicitly supplied Content-Type on POST while retaining
application/json as its default for existing callers.

## Coverage and verification

Rooibos coverage includes document boundaries, UTF-8 size, capability parsing,
authenticated task requests, error messages, confirmation navigation, upload state,
focus restoration, stale responses, cleanup, and shared overlay routing. Native HTTP
fixture cases post synthetic text and JSON to a local test server to check real
Content-Type, authentication, and body transmission. Host coverage checks that fixture.
Device UI automation covers Cancel and Back above the preserved log and uses an
unreachable synthetic session; it never submits application logs to Jellyfin.

These checks are deferred during the open development cycle. Runtime layout,
SceneGraph focus/observer behavior, and a real-server upload require explicitly
authorized verification; implementation alone does not establish they pass.

API reference: [Jellyfin ClientLogController](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/ClientLogController.cs).
