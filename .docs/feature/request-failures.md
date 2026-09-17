# Request failure classification

HttpClient attaches a string-valued failureKind from RequestFailure.Kind to every
failed request. RequestFailure.GetMessage provides a plain-language explanation.
Numeric status, technical errorMessage, responseText where supplied, and
authExpired are retained. Successful responses are unchanged.

| Identifier | Explanation |
|---|---|
| timeout | The server took too long to respond. |
| connectionFailed | Couldn't connect to the server. |
| authenticationRequired | Your session has expired. Please sign in again. |
| accessDenied | The server denied access. |
| notFound | The requested content could not be found. |
| rateLimited | The server is receiving too many requests. Please wait a moment. |
| serverError | The server encountered an error. |
| requestRejected | The server rejected the request. |
| invalidRequest | The app couldn't prepare the request. |
| requestStartFailed | The app couldn't start the request. |
| unexpectedResponse | The app received an unexpected response from the server. |

HTTP 408/504 and Roku transport timeout -28 map to timeout. Authenticated 401
retains authExpired and maps to authenticationRequired; unauthenticated 401 maps
to requestRejected. HTTP 403/404/429 have dedicated identifiers; remaining 5xx
map to serverError and remaining 4xx to requestRejected. Unclassified outcomes
map to unexpectedResponse. Known DNS, connection, and TLS failures map to
connectionFailed; malformed URL/protocol errors map to invalidRequest.

Input validation, request-start failure, wait timeout, and unexpected events are
classified at their origin. TaskRequest validation uses invalidRequest.
TaskResponse preserves identifiers and uses unexpectedResponse for a missing response.

Home prefixes explanations with section/library context. Its deliberate On Now
403 exception still omits that row without changing shared status. Stale response
rejection and authentication expiration remain in their existing owners.
Home unit tests use controlled task nodes without starting network I/O;
controlled device fixtures cover real requests separately.

## Ownership and presentation

`RequestFailure.FromStatus(status)` owns the HTTP/Roku transport mapping. It
takes only the status code; authenticated 401 detection remains in `HttpClient`.
Direct failures such as invalid input, request-start failure, and wait timeout
receive their identifier where they occur.

`RequestFailure.GetDisplayMessage(response, fallback)` first uses a present
`failureKind`, including safe wording for unknown identifiers. Otherwise it
preserves a nonblank app-generated `errorMessage`, then uses the caller fallback.
Screens supply action context for structured failures without prefixing existing
app-generated messages twice. Authentication retains its existing action prefixes.

Authentication, account switching, browsing, search, details, media actions,
artist metadata, and terminal playback request failures use this presentation
contract. Artist metadata failures remain inline in the overview. Playback
recovery still receives technical diagnostics and retains its retry sequence;
only its terminal request-error message changes. Roku player errors are unchanged.

Quick Connect, artist metadata, media actions, and playback wrappers preserve
`failureKind`, numeric `status`, `authExpired`, and technical details alongside
their action, item, and request-correlation fields. `errorMessage` remains useful
for diagnostics and specific app errors such as missing playable media.
Optional failures that were silent remain silent. Home On Now 403 suppression,
Recently Added exclusions, stale-response checks, and authentication routing are
unchanged. No localization, registry, or additional request behavior is introduced.

## Verification

The app-wide migration passed `npm run validate` and an explicit standalone
Rooibos build. The runner reported 2,845/2,845 passing device tests, but a later
detailed-report review found Playlist and TVSeason setup crashes omitted from
that total. That run is not a clean full-suite result; see the MessageDialog
verification for corrected test setup and subsequent results. The test
configuration excludes only the pre-existing ignored localization
`pages/Logs/LogDialog.spec.bs` left by the parked work.

Controlled device fixtures verified authenticated 401 (`authenticationRequired`,
`authExpired`) versus unauthenticated 401 (`requestRejected`), Home failure
messages and exclusions, and short/long Live TV messages. Inspected 1080p
captures show full text, with the longer Live TV message wrapping to two lines.
Local evidence is under `out/app-failure-migration/`.

An existing Live TV issue remains outside this migration: the channel-load error
handler stops loading but leaves the preview text ?Loading Live TV / Fetching
channels and schedule? visible above the error. This wording migration preserves
that behavior; it should be addressed separately.

## Acknowledgment presentation

Shared screen-level messages now use [MessageDialog](message-dialog.md) through
AppMessage.Show. Home combines current-refresh failures into one acknowledgment.
Successful background responses do not dismiss it. RequestFailure wording and
classification remain unchanged. Previous screenshot verification above describes
the preceding centered-label implementation.
