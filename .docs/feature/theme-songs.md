# Theme Songs

Theme song playback support is implemented in the app, but libraries still need
theme song media sourced and attached on the Jellyfin side.

## Current App Support

- The Settings dialog exposes a Theme Music toggle.
- Movie and TV show pages request theme songs from Jellyfin when theme music is
  enabled.
- `ThemeSongsTask` calls Jellyfin's item theme song endpoint:
  `/Items/{itemId}/ThemeSongs`.
- `ThemeAudio` resolves playback info for the returned theme song item and plays
  it through the app shell.
- Theme audio is stopped when navigating away from media pages or starting
  playback.

## Jellyfin Source

Use the Jellyfin Theme Songs plugin to import or manage theme song media:

https://github.com/danieladov/jellyfin-plugin-themesongs

The app expects Jellyfin to expose imported theme songs through the normal
`ThemeSongs` item endpoint. The Roku app does not currently fetch MP3 theme
files directly from third-party URLs.

## Candidate Theme Source

TV theme MP3s can be sourced by TVDB id from:

```
https://tvthemes.plexapp.com/{tvdbId}.mp3
```

Example:

```
https://tvthemes.plexapp.com/74380.mp3
```

`74380` is the TVDB id for Magnum P.I.

```
televisiontunes.com
```

## Open Work

- Decide whether sourcing is a manual library-management step or something
  documented for server setup.
- Confirm how the Theme Songs plugin maps TVDB ids to downloaded theme files.
- Verify that imported theme songs appear in Jellyfin's `/Items/{itemId}/ThemeSongs`
  response for both series and movies.
- Keep the Roku app using Jellyfin-hosted theme song items rather than direct
  third-party MP3 URLs, so playback continues to use the existing authenticated
  media pipeline.
