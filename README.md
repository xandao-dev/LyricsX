# LyricsX

<img src="docs/img/icon.png" width="128px">

Synced lyrics for macOS, shown on the desktop, in the menu bar and in a scrolling lyrics window.

This is a personal fork of [ddddxxx/LyricsX](https://github.com/ddddxxx/LyricsX). Upstream master has not changed since 2022. Known problems are listed in [BUGS.md](.claude/plans/BUGS.md) and planned work in [FEATURES.md](.claude/plans/FEATURES.md).

## What it does

- Reads the current track from macOS Now Playing, where Edge and Chrome publish Spotify, YouTube and YouTube Music. Any other app that shows up in Control Center's Now Playing works the same way.
- Searches NetEase, QQ Music, Kugou and LRCLIB for time-synced lyrics and saves the best match to `~/Music/LyricsX` as an `.lrcx` file. LRCX is LRC plus word timing and translation lines. Plain `.lrc` files work too.
- Shows the current line in a floating desktop overlay, in the menu bar and in the lyrics window. Double click a line in the lyrics window to seek to it.
- Translates the lyrics on your Mac with Apple's Translation framework and shows the translation under each line, in the overlay and the lyrics window. The language is set in Preferences > Display > Translation. Both languages have to be downloaded first in System Settings > General > Language & Region > Translation Languages. The translation is saved in the `.lrcx` file.
- Lyrics offset from the menu bar menu, drag and drop to import lyrics.

## Requirements

- macOS 26 or later. This fork is worked on under macOS 26.5 on Apple Silicon.
- Full Xcode from the App Store. The Command Line Tools alone cannot build this project. `xcodebuild -version` has to print an Xcode version; if it prints `tool 'xcodebuild' requires Xcode`, you only have the Command Line Tools.

## Build

Run everything from the repository root.

### One-time setup

After installing Xcode, make it the active developer directory and accept the license:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

Every dependency is a Swift package. Xcode fetches them on the first build.

### Debug build

```sh
xcodebuild \
  -project LyricsX.xcodeproj -scheme LyricsX -configuration Debug \
  -derivedDataPath Product/DerivedData \
  build
```

The app ends up in `Product/DerivedData/Build/Products/Debug/LyricsX.app` (`Product/` is git-ignored). The project signs ad hoc ("Sign to Run Locally") with the App Sandbox on and Hardened Runtime off, so a plain `xcodebuild` is enough.

### Run

Quit any other copy of LyricsX, then:

```sh
open Product/DerivedData/Build/Products/Debug/LyricsX.app
```

It lives in the menu bar and has no Dock icon. To follow its logs (its own messages start with `CustomLog:`):

```sh
log stream --style compact --predicate 'process == "LyricsX"'
```

### Working in Xcode

Open `LyricsX.xcodeproj` in Xcode and run the LyricsX scheme. Signing is already "Sign to Run Locally".

## Test

The repository has no automated tests. The Xcode project has no test target, so testing means running the app:

1. Build and run as above.
2. Play a song in a browser (Spotify, YouTube or YouTube Music in Edge or Chrome). Within a few seconds the desktop overlay should show the current line and the lyrics window (menu bar icon) should scroll along.
3. Check that `~/Music/LyricsX` has a new `Title - Artist.lrcx` file.

This command prints what macOS itself reports as playing, from any app, without LyricsX running:

```sh
osascript -l JavaScript -e '
ObjC.import("Foundation");
$.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/MediaRemote.framework/").load;
const R = $.NSClassFromString("MRNowPlayingRequest"), item = R.localNowPlayingItem;
const info = item.isNil() ? null : item.nowPlayingInfo, path = R.localNowPlayingPlayerPath;
JSON.stringify({
  title: info ? ObjC.unwrap(info.valueForKey("kMRMediaRemoteNowPlayingInfoTitle")) : null,
  artist: info ? ObjC.unwrap(info.valueForKey("kMRMediaRemoteNowPlayingInfoArtist")) : null,
  app: path.isNil() ? null : ObjC.unwrap(path.client.bundleIdentifier) });'
```

If it prints your song but LyricsX shows nothing, check that LyricsX has a `/usr/bin/perl` child process (`pgrep -lf mediaremote-adapter`). That process is how it reads Now Playing (B1). BUGS.md also has `curl` commands that check each lyrics source directly.

## Install

Build the Release configuration and copy it to `/Applications`:

```sh
xcodebuild \
  -project LyricsX.xcodeproj -scheme LyricsX -configuration Release \
  -derivedDataPath Product/DerivedData \
  build
ditto Product/DerivedData/Build/Products/Release/LyricsX.app /Applications/LyricsX.app
open /Applications/LyricsX.app
```

Use `build`, not `archive`, unless you want a signed archive. The old App Center "Upload dSYM" archive step is gone (B10).

To start it at login, add `/Applications/LyricsX.app` in System Settings > General > Login Items.

This fork uses bundle ID `dev.xandao.LyricsX`, so macOS, Homebrew and any leftover official build treat it as a different app from upstream LyricsX (`ddddxxx.LyricsX`). If Homebrew still has the official cask, uninstall it first or `brew upgrade` will overwrite `/Applications/LyricsX.app`:

```sh
brew uninstall --cask lyricsx
```

To uninstall this fork, quit LyricsX, delete `/Applications/LyricsX.app`, and run `defaults delete dev.xandao.LyricsX`. Downloaded lyrics stay in `~/Music/LyricsX`. To keep preferences from an old official install:

```sh
defaults export ddddxxx.LyricsX - | defaults import dev.xandao.LyricsX -
```

## Credits

LyricsX was written by [Xander Deng (ddddxxx)](https://github.com/ddddxxx) and contributors, and is licensed under the Mozilla Public License 2.0 (see [LICENSE](LICENSE)). Track detection comes from [MusicPlayer](https://github.com/ddddxxx/MusicPlayer) and lyrics search from [LyricsKit](https://github.com/ddddxxx/LyricsKit), both by the same author. Other libraries: [GenericID](https://github.com/ddddxxx/GenericID), [SwiftCF](https://github.com/ddddxxx/SwiftCF), [MASShortcut](https://github.com/shpakovski/MASShortcut), and [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD 3-Clause) for reading Now Playing.

Lyrics belong to their copyright owners.
