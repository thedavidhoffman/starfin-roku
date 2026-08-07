# Changing the Roku Debug IP Address

When a Roku device receives a new IP address, update the VS Code BrightScript debugger
setting before starting a new debug session.

1. Confirm the Roku's current address under **Settings > Network > About** on
   the device.
2. In VS Code, open the Command Palette and select
   **Preferences: Open User Settings (JSON)**.
3. Set `brightscript.debug.host` to the new address:

   ```json
   "brightscript.debug.host": "192.168.0.107"
   ```

4. Stop any active debug session, then run the `Starfin` debug configuration
   again.

The VS Code debugger does not read `rokudeploy.json`. That file is used by the
repository's deployment and log-viewer scripts. Update its `host` separately
when using `npm run deploy` or `npm run logviewer`:

```json
{
  "host": "192.168.0.107",
  "password": "YOUR_ROKU_DEVELOPER_PASSWORD"
}
```

Do not commit `rokudeploy.json`, because it contains the Roku developer
password. Use `rokudeploy.example.json` as the shareable template.
