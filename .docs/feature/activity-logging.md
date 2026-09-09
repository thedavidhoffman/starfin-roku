# Activity Logging

Starfin records concise, user-readable activity entries in the shared log for
major navigation, loading, playback, media-action, and settings events. Activity
entries use the existing timestamp and component label followed by the stable
`Activity:` prefix so they can be filtered separately from diagnostic messages.

## Titles and context

- Item events use the API item's `Name`; episode events include series, season,
  episode, and episode name when available.
- TV-season events include both the show and season names when series metadata
  is available.
- Composite TV titles use plain ASCII hyphens for compatibility with Roku
  consoles, log collectors, and exported text.
- Request events use the request title, with a feature-specific fallback when
  title context is unavailable.
- Missing metadata produces a readable fallback and does not prevent the
  underlying user action.

## Event boundaries

- Opening and viewing are distinct: opening records navigation intent, while
  viewing records successful content readiness.
- Home navigation records `Opening home`; HomePage records `Viewing home` only
  after its blocking refresh is ready.
- Detail and library opening events are emitted by their shared, validated
  navigation boundary so every entry route records exactly one event.
- Home Media folders and nested collections record opening intent before their
  asynchronous loads, followed by the existing viewing event after readiness.
- Search submission is recorded after the trimmed query passes validation and
  request context is available, immediately before task dispatch.
- Video-library browse-option and sort-direction changes record the resulting
  sort label and direction after the selection is accepted.
- Failures are recorded only after the owning workflow accepts the response as
  current.
- Playback pause, resume, stop, completion, and track changes are recorded only
  when the normalized state changes, preventing repeated observer notifications
  from duplicating activity.
- Audio, subtitle, and video-mode selections are recorded only after a local
  subtitle change is committed or a valid playback restart is ready to dispatch.
- TV-season readiness is recorded only after any requested deep-link episode
  focus succeeds; an unavailable destination records failure without readiness.
- Photo viewing is recorded when the requested image becomes the displayed
  image, not merely when loading begins.
- Activity entries flow through `Logger.activity()` and the shared `LogService`;
  they remain available anywhere the normal application log is displayed.
