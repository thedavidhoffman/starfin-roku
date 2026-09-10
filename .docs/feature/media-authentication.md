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
