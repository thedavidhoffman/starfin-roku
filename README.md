[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/thedavidhoffman)

# Introduction

Starfin is a modern, full-featured Jellyfin client for Roku devices. It provides a polished interface for browsing and playing movies, TV shows, music, playlists, and Live TV from a Jellyfin server.

This app was built from the ground up and is not a fork of any other Jellyfin Roku app.

## Why did I make Starfin? What does it offer vs the Roku clients already out there?

I personally wasn't happy with the official Jellyfin Roku client, Moonfin, or JellyRock. No offense to any of the fine folks working on those apps, they just didn't offer a client experience that could lure me away from Plex. So I made something that had a UI that I would be happy with as my daily driver with lots of consideration for workflows, vertical TV episode navigation, reduced remote navigation, and lots of options for library layout/presentation. Something more like the refinements you find in the Plex app, but also improving on the things in the Plex app I don't like.

![Splash](images/splash-fhd.png)

![Home](screenshots/home.jpg)

![Movies](screenshots/movies.jpg)

![Movie](screenshots/movie.jpg)

![TV Series](screenshots/tv-series.jpg)

![TV Season](screenshots/tv-season.jpg)

![Account Switcher](screenshots/account-switcher.jpg)

![Video Settings](screenshots/settings-video.jpg)

## Installing

### Starfin is available on the Roku app store. But you can also sideload it if you like.

### Sideload Video Instructions

The official Roku Developer YouTube channel has a helpful video that walks through how to sideload a Roku app. You can skip the intro; this link starts at the 26-second mark.

https://youtu.be/r9HhUIWA4L0?si=OGK6Tm1SdCcLLhN-&t=26

### Sideload Written Instructions

1. On the Roku remote, press `Home` three times, `Up` two times, then `Right`, `Left`, `Right`, `Left`, `Right`.
2. Follow the on-screen prompts to enable the Developer Application Installer.
3. When the "Developer Settings" screen displays...
   - Note the `IP address`.
   - Note the username (it's always `rokudev`)
4. Read and accept the license agreement.
5. Set and note the developer web server password.
6. Restart the Roku device when prompted.

After the Roku device restarts, upload the Starfin app:

1. Find the Roku IP address under `Settings > Network > About`.
2. Download the Starfin app zip file from the [latest Starfin GitHub release](https://github.com/thedavidhoffman/starfin-roku/releases).
3. In a browser, open `http://ROKU_IP_ADDRESS`.
4. Sign in with username `rokudev` and the developer password you set.
5. Use the upload form to select the Starfin zip file from the most current release in this GitHub repository, then click `Install`.

After installation, Starfin will be available from the Roku home screen.

## Legal/Policies

- [License](LICENSE)
- [Privacy Policy](PRIVACY-POLICY.md)
- [Terms of Use](TERMS-OF-USE.md)

## AI Usage Disclaimer

Starfin is AI coded using Codex. But it's not AI slop, check the commit history, check the code, try the app, and make your own conclusions.

## QA/Testing

Each release has a [readiness assessment](.docs/release-readiness-review.md) that is performed that executes the following:
1. Identifies the last known-good release tag and reviews the diff from that baseline to the proposed release commit, performing a high-level code review of that diff.
2. Runs over 3,000 [rooibos](https://github.com/rokucommunity/rooibos) based unit tests.
3. Runs [RTA](https://github.com/rokucommunity/roku-test-automation/) based automated tests at both 1080p and 720p.

The readiness assessment generates the following artifacts that are bundled in the release.
1. release-readiness-report.md
2. unit-test-report.txt
3. starfin-automation-report-1080p (with screenshots)
4. starfin-automation-report-720p (with screenshots)

## Development

See [README.DEV.md](README.DEV.md) for contributing, setup, build, deployment, debugging, and logging instructions.
