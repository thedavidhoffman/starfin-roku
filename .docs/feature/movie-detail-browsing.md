# Movie Detail Browsing

Movie detail pages opened from the video library expose previous and next title
controls in the cinematic layout. Selecting either control updates the existing
Movie page with the chosen library item and preserves the library browse index.

Movie metadata loading uses the shared `LatestRequestLifecycle` helper. The page
keeps one active `MovieTask` request and replaces a single pending request
whenever the user navigates again while that task is running. Every request gets
a monotonically increasing `requestId`, which `MovieTask` echoes on success and
failure. Only the response for the latest generation may commit page state. A
stale response advances the pending request without rendering old metadata or
ending the loading state.

The page alternates between two `MovieTask` nodes. A stale response therefore
starts the pending request on the idle node instead of trying to restart the Task
that is still completing its response rendezvous.

The shared spinner remains active across stale responses and is hidden only
after the current title's metadata request succeeds or fails. This allows rapid
previous/next navigation to settle on the final title without leaving the page
partially rendered or permanently loading.

Activation and deactivation follow the shared media-detail focus contract. The
page deactivates Cast and previous/next controls, releases page focus, cancels
detail loading, and clears the spinner when leaving. Returning restores page
focus through the saved focus area.

Movie request orchestration lives in the component-local `Helpers/Loading.bs`
file. It owns load-request changes, latest-request dispatch and completion, and
movie theme-song lookup while continuing to operate in the Movie component's
context. This matches the responsibility split used by TVEpisode without moving
page state or Task ownership into a separate component.
