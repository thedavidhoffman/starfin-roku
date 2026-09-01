# Quick Connect

Starfin supports Jellyfin Quick Connect as an alternative to entering a username
and password with a Roku remote. The user enters a server address, selects
**Quick Connect**, and approves the displayed code from a Jellyfin client where
they are already signed in.

The Jellyfin user that approves the code is the account Starfin authenticates and
saves. Existing manual sign-in and saved-account behavior remain unchanged.

`AuthController` owns the complete workflow and is the only component that commits
the resulting session. It initiates Quick Connect, polls at three-second intervals,
authenticates an approved secret, and routes the returned user and access token
through the same `AuthStore` path as password login. Cancellation advances a
generation identifier so late task responses cannot authenticate.
Two bounded task slots track in-flight work explicitly; if both are occupied,
only the newest request is retained and dispatched when a slot becomes free.

The login page owns presentation only. Quick Connect appears beside Sign In in
an equal-width action row, with Saved Accounts occupying the full row below.
While Quick Connect is active it replaces
the credential form with the code, instructions, status, and a Cancel button.
Cancel or Back restores the form without clearing entered values. Secrets and
access tokens are never exposed through presentation state or logs.
