# Set up Pluto TV in Jellyfin

This guide adds US Pluto TV channels and program guide data to Jellyfin. It can
be used to create DVR content for investigating
[Starfin issue #56](https://github.com/thedavidhoffman/starfin-roku/issues/56).

These are unofficial, community-maintained sources. The playlist was confirmed
to be available during setup research, but playback and recording have not been
verified in Jellyfin.

## Add the M3U tuner

1. Open Jellyfin's web interface with an administrator account.
2. Go to **Dashboard → Live TV**.
3. Under **Tuner Devices**, click **+** and select **M3U Tuner**.
4. Enter the following URL in **File or URL**:

   ```text
   https://raw.githubusercontent.com/BuddyChewChew/pluto/refs/heads/main/pluto_us.m3u
   ```

5. Save the tuner.

## Add the XMLTV program guide

The guide provider is configured separately from the M3U tuner. If you are still
in the tuner editor, save it and return to the main **Dashboard → Live TV** page.

1. Scroll below **Tuner Devices** to **TV Guide Data Providers**.
2. Click **+** and select **XMLTV**.
3. Enter the following URL in **File or URL**:

   ```text
   https://github.com/matthuisman/i.mjh.nz/raw/master/PlutoTV/us.xml.gz
   ```

4. Save the guide provider and allow the guide data to refresh.
5. If channels do not have guide listings, open the guide provider's **…** menu,
   select **Map Channels**, and match the tuner channels to their guide entries.

## Try playback and create a recording

1. Open **Live TV** in Jellyfin's web app and check that the guide has listings.
2. Play a channel to confirm the stream works on your server.
3. Select a program from the guide and schedule a short recording.
4. After recording finishes, confirm it is available in Jellyfin, then try opening
   **Recordings** from Starfin's media menu to investigate issue #56.

## References

- [Jellyfin Live TV setup guide](https://jellyfin.org/docs/general/server/live-tv/setup-guide/)
- [Community Pluto TV playlist repository](https://github.com/BuddyChewChew/pluto)


## Additional Providers

| Option | Why consider it? | Jellyfin setup |
|---|---|---|
| **Samsung TV Plus** | Alternative lineup of free streaming channels | Community M3U playlists and guide feeds are available. [Playlist project](https://github.com/BuddyChewChew/app-m3u-generator) |
| **Plex / The Roku Channel** | More free channel choices | The same project provides unofficial playlists; playback and DVR need testing. [Playlist project](https://github.com/BuddyChewChew/app-m3u-generator) |
| **IPTV-org** | Broad selection of public streams from around the world | M3U playlists; guide data is handled separately. [Project](https://github.com/iptv-org/iptv) |