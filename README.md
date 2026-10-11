# Historial

[Español](README.es.md)

Historial is a small native macOS clipboard history app. It lives in the menu bar and opens with a configurable global shortcut (**⌥V** by default). It stores recent text, images, and file references locally, with search and previews to help you find a previous copy quickly.

> Early preview. The downloadable build is unsigned and not notarized. The global shortcut and automatic paste still need hands-on verification with the required macOS permissions.

## Download

Download the Apple Silicon ZIP from [Releases](https://github.com/drodri-es/historial-macos/releases), unzip it, and move `Historial.app` to Applications. Requires macOS 15 or later. This build does not support Intel Macs.

Because the app is not signed with an Apple Developer ID, macOS may block its first launch. After trying to open it, go to **System Settings → Privacy & Security** and choose **Open Anyway** for Historial. See [Apple’s instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). Only make this exception if you trust the download.

## Features

- Restore a selected item to the clipboard and attempt to paste it into the previously active app.
- Search recent items and preview text, images, and files.
- Keep history across launches, with a configurable item limit and expiry.
- Pause capture, exclude apps by bundle ID, and clear history.
- Switch the interface between English, Spanish, and the system language without restarting.
- Keep clipboard data on this Mac. The app has no sync or network feature.

File entries store their original paths. Historial does not move or change the files; an entry cannot be restored if its original file is gone.

## Build and run

Requires macOS 15 or later and Apple command line developer tools. On a Mac, run:

```sh
zsh scripts/build-app.sh
open dist/Historial.app
```

The build script creates `dist/Historial.app` and signs it locally with an ad hoc signature. It does not create a notarized distribution build. The generated app and build cache are excluded from Git.

## Permissions and fallback

macOS may ask for clipboard access when Historial reads copied content in the background. Automatic paste also requires **Accessibility** permission in System Settings because the app sends a paste keystroke to the previously active app. If Accessibility is not granted, selecting an item still restores it to the clipboard; press **⌘V** in the target app to paste it manually.

## Use

1. Copy text, an image, or a file in another app.
2. Press **⌥V** or click the clipboard icon in the menu bar.
3. Search if needed, then select an item. Use **↑/↓** and **Return** for keyboard selection.
4. Open **Settings** to change the shortcut, language, history limits, expiry, pause state, or excluded apps.

History is saved only in `~/Library/Application Support/Historial/history.json`. Use **Clear history** in Settings to remove saved entries.

## Source layout

- `Sources/Historial/App.swift`: menu bar app, shortcut, and paste flow.
- `Sources/Historial/Core.swift`: clipboard capture and local persistence.
- `Sources/Historial/UI.swift`: history panel and settings.
- `Sources/Historial/Resources`: English and Spanish strings.
- `scripts/build-app.sh`: local app bundle build.

## License

MIT. See [`LICENSE`](LICENSE).
