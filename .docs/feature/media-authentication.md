# Media Authentication

Jellyfin video, music, theme audio, and trickplay downloads use the
`Authorization` header with the `MediaBrowser` scheme. Each playback item uses
its request's session credentials through `JellyfinAuth.BuildMediaRequest`.
`JellyfinAuth.CreateContent` creates audio and video content with its URL and
`HttpHeaders`. Callers supply playback-specific fields such as title and format.

`Url` owns URL resolution and origin comparison. `JellyfinAuth`
owns the credential policy used by media consumers.

Jellyfin credentials are sent only to the configured server's origin. External
media URLs receive no Jellyfin session header.

Server-provided playback and subtitle URLs retain their query parameters and
fragments. Relative URLs resolve against the configured server's base path.
Subtitle tracks use the supplied delivery URL without adding credentials.

TMDB authentication is separate. Authentication tokens are redacted from logs.

## HTTPS and Roku device identity

The shared HTTP client and trickplay downloader use Roku's CA bundle through
`SetCertificatesFile("common:/certs/ca-bundle.crt")` for HTTPS server-certificate
verification. They do not call the deprecated `InitClientCertificates()` API,
which presents a Roku-issued client certificate to servers requesting device
authentication. Jellyfin requests retain their existing session authorization.

Roku device attestation is not part of this request contract. Adding it would
require backend verification of attestation tokens; it is not a replacement for
HTTPS server-certificate verification or Jellyfin session authentication.

Existing HTTP-client and trickplay tests cover authenticated requests and tile
downloads through the local HTTP fixture. They do not establish HTTPS certificate
behavior. Device verification for this change should cover HTTPS sign-in/API
requests and trickplay downloads, followed by Roku static analysis of the new
package to confirm the deprecated-API warnings are gone.

## Feature-owned session expiry

ThemeAudioController and TrailerDialog emit an always-notified
`authenticationRequired` event containing `{ request, response }` only after
their current-request lifecycle accepts a Jellyfin authentication failure.
They stop their work before publishing. MainScene observes the controller and
receives trailer events through OverlayHost, matches the captured server, user
ID and nonempty token against the current session, and delegates to the existing
account-expiry route. Superseded, cancelled, duplicate and previous-session
responses cannot expire a replacement session.

Trailer catalog failures preserve status, authentication and failure details.
Authentication failures do not also display the generic trailer retry dialog.
Access denial, transport failures and YouTube errors retain their existing
feature behavior; trailer encoding cleanup remains best-effort. Component
coverage exercises owner cancellation, failure classification and shell routing.
