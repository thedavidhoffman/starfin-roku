# Sign In

Sign in requires a server address and username. Passwords may be empty for
Jellyfin accounts without a password; the server decides whether credentials
are accepted. Passwords are sent exactly as entered, including whitespace.

Server addresses are normalized and usernames are trimmed before submission.
Authentication failures keep the sign-in screen open and display the server
request error. Successful authentication follows the shared session and saved
account flow.

## Local server discovery

Pressing OK on the server field opens a top-level server picker. An empty field
shows **Press OK to choose a server**; a populated field shows its current URL.
It scans only on request, broadcasting Jellyfin discovery on UDP 7359 at zero,
two, and four seconds and collecting responses for six seconds. A dedicated
Task owns the socket; the discovery dialog owns scan lifecycle and cancellation.
MainScene only routes the overlay request and selected result back to Login.

The picker displays server names and advertised URLs, sorted by name then URL.
Responses are deduplicated by server ID or address. Invalid replies are ignored.
Custom ports and base paths are preserved; discovery does not guess addresses,
probe HTTP endpoints, persist results, or authenticate automatically.

A user must select a result even when only one is found. Selecting a different
normalized address clears username and password and focuses username. Selecting
the same address preserves credentials. The existing address observer refreshes
Saved Accounts. Cancel or Back preserves the form and focuses the server field.
During every scan the list is hidden, Search Again is disabled, and Cancel has
focus. The searching layout reserves one list row (104px including spacing)
between the status and footer. Scan completion highlights the first server, or
**Enter server address manually** when no servers are found. Empty results and socket errors have
separate inline messages. Closing or replacing the overlay cancels its task and
ignores late results; retries use a fresh task after the previous one finishes.

The final list row is **Enter server address manually**, separated from discovered
servers and available after scanning, including empty results or socket failure. It
opens a Roku keyboard prefilled with the current address. Empty input keeps the
keyboard open with validation; Save normalizes the address and uses the same
selection path as discovery. Keyboard Cancel or Back returns to the manual row.
The picker owns that keyboard and closes only its own keyboard during cleanup.

The completed status is **Select a server...**. The list sits 16 pixels below
the rendered status, with standard-height Search Again and Cancel buttons below
it. Rows show server name and full URL. The list uses the shared transparent focus
footprint and restores normal text colors when focus moves away. Subsequent list updates preserve
the focused row by server identity or the manual-entry action; an open keyboard
retains focus. Each completed scan starts at the first available option.

Quick Connect uses the selected address. Discovery requires the Roku
and server to have local-network UDP connectivity, including container exposure
of UDP 7359 and a correct published server URL. Device discovery must be verified
on the Roku, independently of successful desktop discovery.

Credential keyboards are owned by Login. Save, Cancel, and native Back restore
focus to the originating field; hiding Login closes only its own keyboard.
Callbacks from retired keyboards cannot change form values or close a replacement.
Login uses one navigation table for field targets, directional movement, and focus visuals.

Closing the picker is terminal: it detaches content observers, cancels discovery,
and rejects queued retry or selection callbacks. OverlayHost likewise detaches
retired overlay observers and checks the sender before routing events.
The picker content reports its own height; the shared Dialog adds frame spacing.
