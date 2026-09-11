# MusicPlayer

Track detection for LyricsX, vendored from [ddddxxx/MusicPlayer](https://github.com/ddddxxx/MusicPlayer) v0.8.3 and cut down to what the app uses.

- `SystemMedia` reads macOS Now Playing, which browsers publish too. It goes through [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), so the app has to embed `MediaRemoteAdapter.framework` in `Contents/Frameworks` (the `MediaRemoteAdapter` target in the Xcode project does that). Without the framework, `SystemMedia()` returns nil.
- `Agent` forwards another player's state and commands.

The AppleScript players (Music, Spotify, Vox, Audirvana, Swinsian), the iOS players and MPRIS are gone.

## License

MusicPlayer is part of LyricsX and licensed under MPL 2.0. See the [LICENSE file](LICENSE).
