# Sign In

Sign in requires a server address and username. Passwords may be empty for
Jellyfin accounts without a password; the server decides whether credentials
are accepted. Passwords are sent exactly as entered, including whitespace.

Server addresses are normalized and usernames are trimmed before submission.
Authentication failures keep the sign-in screen open and display the server
request error. Successful authentication follows the shared session and saved
account flow.
