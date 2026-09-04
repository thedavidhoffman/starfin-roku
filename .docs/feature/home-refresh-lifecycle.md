# Home Refresh Lifecycle

Home data loads use a generation and account-session identity so only the
current refresh may update shelves, loading state, or focus. Every full or
playback-row refresh invalidates the prior generation and cancels its owned
Task nodes before creating a fresh bounded set of one-shot tasks.

Each task receives `homeQueryId` and `homeSessionKey` in its private request
snapshot. Response handlers verify the task is still the action's owned node and
that both values match current Home state. Stale success and failure responses
therefore cannot render data, clear the spinner, publish an error, or complete a
newer blocking refresh. The account key is preferred as session identity, with
normalized server and user ID used when no account key is available.

Core task nodes retain their established IDs while the completed refresh is
visible so device automation can inspect their terminal states. They are
detached when superseded. Per-library Latest Media tasks are detached as each
response completes.

Home and Live TV attach dynamically created tasks beneath their owning page and
publish the task through `taskCreated`. MainScene observes that event and adds
the standard authentication-response observer before the task runs. A 401 from
a dynamic Latest Media or Live TV schedule request therefore expires only the
matching active account through the same path as declarative task nodes.
