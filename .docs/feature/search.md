# Search

Search requests run one at a time. A valid submitted query shows the shared
blocking spinner immediately and suppresses duplicate submissions until the
request succeeds, fails, or is cancelled. This prevents the same `SearchTask`
from being restarted while its current execution is still finishing.

Search opts into cancellation on the shared spinner. Pressing Back while a
search is running stops the task, invalidates its asynchronous lifecycle, hides
the spinner, and restores focus to the Search button. Late responses are ignored.
Other blocking-spinner users do not enable cancellation, so Back remains blocked
for those workflows.

After cancellation, the page remains unblocked but suppresses new submissions
until the Task `state` confirms `stop`, `done`, or `init`. This prevents an
immediate resubmission from issuing `run` while the cancelled Task is still
stopping.

Successful and failed current responses both release the blocking spinner.
Leaving Search also cancels any active request, disables spinner cancellation,
and removes the page's spinner observer.
