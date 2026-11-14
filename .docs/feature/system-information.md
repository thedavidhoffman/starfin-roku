# System Information

The System Information dialog displays application details, Roku device details,
global application registry settings, and saved-account settings. The content
component collects these sections; the shared `SectionedInformation` control
renders and scrolls them.

## App registry usage

The final row in **Roku Device Information**, immediately after **connection info**,
is **app registry usage**. Its value uses exact bytes, for example
`6144 / 32768 bytes used`.

Each information refresh reads `roRegistry.GetSpaceAvailable()` and subtracts
the available bytes from Roku's 32768-byte registry capacity. Opening the dialog
refreshes the information. The value covers the app's total registry usage,
including all saved accounts and settings, rather than just the active account.
Collecting this usage value does not write to the registry.

The capacity and available-space API are documented in the
[Roku registry reference](https://developer.roku.com/dev/docs/ifregistry).

## Account key display

Both `active-account-key` and `account-key` display the stored account key directly,
using the `<hostname[:port]>/<user-id>` format.

## Coverage

The `SystemInformationContent` component suite covers direct account-key display,
final-row placement,
exact-byte formatting for partial, empty, and full usage, and rendering the
current registry usage through `updateSystemInformation` on a fresh production
component instance.
