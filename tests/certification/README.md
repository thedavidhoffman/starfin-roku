# Roku App Behavior Analysis authentication scripts

Upload `starfin-sign-in.rasp` and `starfin-sign-out.rasp` in the Developer Dashboard's Sign In/Out Scripts section. These are Roku Remote Tool RASP v1 scripts, separate from the JavaScript RTA suite.

## Test account

- Server: `https://demo.jellyfin.org/stable`
- Dashboard test username: `demo`
- Dashboard test password: empty

The sign-in script uses both `script-login` and `script-password` substitutions. It opens the password dialog and enters the substituted password. The demo account requires an empty password; do not enter a dummy password in the dashboard. Whether the portal accepts and correctly executes an empty password substitution remains unverified. If it requires a nonempty password, use a password-protected reviewer account and update the server URL and credentials accordingly.

The demo service is externally managed; availability, accounts, and content can change. Deep-link content IDs supplied in the dashboard must refer to this same server.

## Starting state and navigation

Sign-in requires a fresh, logged-out installation with empty server, username, and password fields and Server Address focused. It types directly into each field without clearing existing text. Repeating sign-in after logout with retained field values can fail; restore the empty starting state before rerunning. It saves each StandardKeyboardDialog using four Down presses and OK, then submits the form and waits for Home. Roku's cloud test starting state remains unverified.

Sign-out starts on the authenticated Home page. Up presses move to the header, Left wraps from Home to the account menu, and OK / Down / OK chooses Logout. Twelve Up presses cover the demo Home shelves. The script does not use Home or Back to exit the app.

`launch: Starfin` does not reliably reset an already-running app from an arbitrary detail or playback screen. When testing locally, first return to Home for sign-out or the login form for sign-in. Confirm Roku's cloud test leaves a compatible starting state; neither script is a general-purpose recovery sequence.

The channel mapping uses `dev`, following Roku's sample for a sideloaded application. In Roku Remote Tool, map Starfin to the installed app ID when testing a store installation. Confirm the app mapping in the Dashboard preview for the uploaded package.

## Validation

The upload files use a positive integer wait of one second and only flat `launch`, `press`, `text`, and `pause` steps.

On September 13, 2026, the current sign-out and sign-in scripts were replayed locally through ECP on the development Roku. Sign-out returned to the login form. Retained server and username values were manually cleared as preparation, and all three fields were confirmed empty with Server Address focused before sign-in. This prepared the required form state; it was not a fresh installation.

The sign-in replay used the current RASP actions and waits, with `script-login` substituted as `demo` and `script-password` as an empty string. It reached Home. Launching `contentID=c002f0f88ee970cce7f138bbc925de64&mediatype=movie` then produced Roku media-player state `play`. Exiting Starfin and launching the same deep link again also reached `play`, verifying session persistence across app restart. Playback was stopped after verification. The sign-in result, script SHA-256, starting-state UI capture, and playback evidence are under `out/certification/`.

The local replay treats empty text as no characters to send. It does not verify Roku Remote Tool or the portal's handling of empty credential substitutions, cloud setup ordering, or cloud starting state. These local results do not establish App Behavior Analysis acceptance or certification success.

No production application changes or automation-only interfaces are needed. Private UI inspection output belongs under `out/certification`, not in the submission files.

Reference: https://developer.roku.com/dev/docs/authenticated-cert-testing
