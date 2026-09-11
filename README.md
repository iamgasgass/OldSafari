# OldSafari

> A standalone, modern iOS rebuild of Safari from **The OldOS Project** (v2.0.8), preserving the classic iOS Safari visual language while bringing its browsing experience to current iPhones running iOS 16 or later.

[![iOS](https://img.shields.io/badge/iOS-16.0%2B-0A84FF?logo=apple&logoColor=white)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)](#technology)
[![Build](https://img.shields.io/github/actions/workflow/status/iamgasgass/OldSafari/build.yml?branch=main&label=build)](https://github.com/iamgasgass/OldSafari/actions)
[![License](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey)](#license-and-attribution)

## Overview

**OldSafari** is a native browser app inspired by the Safari implementation shipped with The OldOS Project v2.0.8. It retains the recognisable iOS-era visual identity: brushed blue-grey chrome, glossy address field, classic navigation controls, tab-count button, and the original bookmark and history glyphs.

This is not a theme layered over the system browser. OldSafari is rebuilt as a standalone SwiftUI application using `WKWebView`, with an edge-to-edge layout designed for current iPhones and iOS 16+. It pairs a deliberately retro interface with practical browser features such as multiple tabs, Private Browsing, history, bookmarks, desktop-site requests, Find on Page, system URL handling, sharing, and tactile feedback.

## Highlights

- Faithful iOS-style skeuomorphic Safari chrome, rebuilt for a modern full-screen layout.
- Native WebKit rendering through `WKWebView`.
- Reactive tab state based on Combine and `WKWebView` key-value observation, without polling.
- Multiple normal and private tabs with a Safari-style thumbnail grid.
- Inline loading progress, HTTPS indicator, and reload/stop control.
- Unified local library for bookmarks and browsing history.
- Modern browser actions including Find on Page, Request Desktop Website, native share sheet, and copy link.
- A complete Downloads manager built on `WKDownload`, with an iOS 6 styled confirmation alert, live per-file progress rendered with the exact same glossy fill as the address bar, persistent download history across app launches, and Open / Share / Delete actions.
- Custom-built iOS 6 styled JavaScript `alert()`, `confirm()`, and `prompt()` panels, replacing the modern system `UIAlertController` chrome for web-triggered dialogs.
- Reader Mode with automatic per-page availability detection.
- A per-tab Content Blocker toggle, persisted across sessions.
- Long-press context menus on links and images, including Save Image to Photos.
- Proper handoff of external schemes such as `tel:`, `mailto:`, and `maps:` to iOS.
- An unsigned IPA build workflow for GitHub Actions.

## Interface Fidelity

### Safari Chrome

OldSafari recreates the distinctive hardware-like appearance of classic Safari rather than replacing it with contemporary flat UI.

- Dual-intensity metallic gradients on the navigation bar and bottom toolbar.
- Brushed blue-grey finish in normal browsing mode.
- Rounded, glossy address field with an integrated loading indicator.
- Physical-style controls with rounded contours, inner shadows, and glass-like reflections.
- Classic back, forward, action, bookmarks, and tab-count toolbar controls.
- OldOS-derived Safari icon assets retained in `Assets.xcassets/Safari Icons`.
- The same glossy loading-fill treatment used by the address bar is reused verbatim inside the Downloads list, so per-file progress reads as part of the same visual language rather than a generic bar.
- JavaScript alert, confirm, and prompt panels are rebuilt with the classic navy gradient card, embossed text, and glossy pill buttons instead of the flat system alert.

### Private Appearance

Private Browsing has a complete dark visual treatment rather than a simple tint change.

- Charcoal and midnight-blue metallic bars.
- Dark forms and lists that retain the same skeuomorphic language.
- A dedicated private-mode explainer for new private tabs.
- A direct control in the tab manager to enter or switch browsing mode.

## Browser Capabilities

### Navigation

| Capability | Behaviour |
|---|---|
| Back and Forward | Uses the current web view's navigation history. |
| Reload and Stop | A single inline address-bar control changes according to loading state. |
| Loading Progress | A glossy blue progress bar is rendered inside the URL-field rectangle. |
| HTTPS Indicator | A lock indicator is shown for secure HTTPS destinations. |
| Address Entry | The address field is used for direct web navigation. |
| Desktop Website | Requests the desktop version of a site. |
| Find on Page | Uses the native iOS 16 find interaction to search page content. |
| External Schemes | Routes system-owned schemes such as `tel:`, `mailto:`, and `maps:` to iOS. |
| Full-Screen Layout | Chrome extends behind the status-bar and Dynamic Island area, following modern Safari conventions. |
| Pull to Refresh | A swipe-down gesture on the page reloads the active tab, in addition to the address-bar reload control. |
| Reader Mode | Automatically detects article-like pages and offers a distraction-free Reader view, rendered with the app's own Helvetica Neue styling, toggled from a glyph next to the page title. |
| Content Blocker | A per-tab Content Blocker switch, defaulting to enabled and persisted across sessions per the app's stored preference. |

### Tabs

| Capability | Behaviour |
|---|---|
| Multiple Tabs | Maintains multiple browser tabs through a central tab store. |
| Active Tab State | Keeps the active tab, title, URL, load state, and navigation state synchronised with the UI. |
| Tab Switcher | Presents open tabs in a thumbnail grid for fast switching. |
| Tab Count | Displays the current tab count through the classic Safari tab-count control. |
| New Tabs | Opens blank tabs on a Favorites start page. |
| Close Tabs | Supports tab closing with tactile feedback. |
| Private Tabs | Supports Private Browsing alongside the normal browsing experience. |
| Session Restoration | Restores up to eight previously open tabs on a cold launch, deferring each page's network request until its own tab is actually mounted on screen, so relaunching with several pages open costs one request instead of many. |
| Links Opening in a New Tab | Links opened with `target="_blank"`, `window.open()`, or the long-press "Open in New Page" action create a new tab that is brought to the foreground and displayed automatically, with any open overlay (tab grid, library, share sheet) dismissed so the new page is never hidden behind it. |

### Bookmarks and History

OldSafari includes a locally managed library with a shared iOS-style presentation.

| Capability | Behaviour |
|---|---|
| Unified Library | Bookmarks and History share one sheet, selected with a bottom segmented switch. |
| Add Bookmark | Saves the active page to local bookmarks. |
| Edit Bookmark | Allows bookmark information to be updated. |
| Remove Bookmark | Uses the original red removal glyph for delete actions. |
| History Logging | Stores browsing history locally. |
| History Grouping | Groups entries into Today, Yesterday, and dated sections. |
| Swipe to Delete | Deletes individual history entries by swiping. |
| Clear History | Provides a confirmation flow before clearing all history. |
| Library Styling | Uses an iOS-era fabric/background finish and a glossy blue Done button. |

### Downloads

OldSafari implements a complete download pipeline on top of `WKDownload`, presented with the same skeuomorphic chrome as the rest of the browser.

| Capability | Behaviour |
|---|---|
| Download Detection | Any response the browser cannot render inline — `Content-Disposition: attachment`, `application/octet-stream`, and well-known binary extensions such as `.ipa`, `.apk`, `.exe`, `.dmg`, `.pkg`, and `.deb` — is routed to the download pipeline instead of being loaded as a page, even when a CDN mislabels or omits the `Content-Type` header. |
| Download Confirmation | Before any file is written to disk, a classic iOS 6 styled alert asks the user to confirm or cancel — "Do you want to download '<file>'?" — mirroring modern Safari's own download prompt. |
| Live Progress | Each in-progress download renders the exact same glossy progress-fill treatment as the address bar's own loading indicator, with a live numeric percentage displayed inside the bar. |
| Blob Downloads | Pages that generate files client-side via `URL.createObjectURL` (Google Drive exports, GitHub archive links, Wikipedia PDFs) are bridged into the same download pipeline as ordinary server responses. |
| External Scheme Handoff | Links that trigger a non-web scheme instead of a direct file — such as `itms-services://` OTA install manifests — are handed off to iOS instead of being opened as a blank browser tab. |
| Persistence | Completed downloads are recorded in a small on-disk manifest and restored on the next launch; any entry whose file was deleted outside the app is silently pruned rather than shown as broken. |
| File Management | Completed downloads can be opened in the Files app, shared through the system share sheet, or deleted — deletion removes the underlying file from disk, not just the list entry. |
| Toolbar Badge | A notification badge on the toolbar's Downloads button tracks active and recently finished downloads, and the panel automatically reveals itself the first time a download starts. |

### JavaScript Panels

| Capability | Behaviour |
|---|---|
| Alert / Confirm / Prompt | Pages that call `alert()`, `confirm()`, or `prompt()` are presented with a custom-built panel matching the classic iOS 6 alert chrome — navy gradient card, glossy pill buttons, and embossed white text — instead of the modern system `UIAlertController`. |

### Long Press and Link Actions

| Capability | Behaviour |
|---|---|
| Link Menu | Long-pressing a link offers Open, Open in New Page, Copy Link, Download Linked File, and Share. |
| Image Menu | Long-pressing an image offers Save Image, saved directly to the Photos library through the add-only permission so the app never needs full photo library access. |

### Share and Page Actions

- Native iOS share sheet for sharing the current page.
- iOS-style dark action sheet with rounded, glass-like presentation.
- Add the current page to bookmarks.
- Copy the current page URL to the pasteboard.
- Cancel safely without changing browser state.

## Architecture

The codebase is organised around a small set of app-specific models, a central store, SwiftUI screens, and WebKit integration.

```text
OldSafari/
├── .github/
│   └── workflows/
│       └── build.yml                  # GitHub Actions unsigned IPA build
├── OldSafari.xcodeproj/               # Xcode project
├── OldSafari/
│   ├── OldSafariApp.swift             # Application entry point
│   ├── Models/                        # SafariTab, SafariBookmark, SafariHistoryEntry, SafariDownload
│   ├── Store/                         # SafariTabStore: tabs, bookmarks, history, private mode
│   │                                  # SafariDownloadManager: WKDownload lifecycle, progress, persistence
│   ├── Views/                         # Browser chrome, web view, library, tabs grid, start page,
│   │                                  # Downloads panel, custom JavaScript alert controller
│   ├── Support/                       # Shared colour palette and notification names
│   └── Assets.xcassets/               # Original OldOS Safari assets and app icon
├── README.md
└── LICENSE
```

### State Model

`SafariTabStore` is the central owner of browser-facing app state, including tabs, the selected tab, bookmarks, history, and Private Browsing state. Views render that state and send user actions back to the store, avoiding independent copies of browser data across the interface.

Each browser tab is represented by a `SafariTab`. Bookmark and history data are represented by `SafariBookmark` and `SafariHistoryEntry`, respectively. The app uses Combine together with observation of `WKWebView` properties to reflect loading, title, URL, and navigation changes reactively rather than through timed polling.

Downloads are owned by a separate `SafariDownloadManager` singleton, mirroring the same pattern: it tracks every `SafariDownload` through its lifecycle via `WKDownloadDelegate` and KVO on the underlying `Progress` object, and persists a lightweight, `Codable` snapshot of completed downloads to Application Support so download history survives an app relaunch without ever storing an absolute file path that could go stale between launches.

## Technology

| Area | Technology |
|---|---|
| Language | Swift |
| User Interface | SwiftUI |
| Browser Engine | WebKit / `WKWebView` |
| Reactive State | Combine and `WKWebView` KVO |
| Downloads | `WKDownload`, `WKNavigationAction.shouldPerformDownload`, and a JSON manifest persisted to Application Support |
| Application Pattern | Models, central Store, and SwiftUI Views |
| Target Platform | iPhone on iOS 16.0+ |
| CI Build | GitHub Actions |

OldSafari relies on Apple platform frameworks for its primary UI, browser, sharing, haptic, and system-integration behaviour.

## Requirements

- macOS with Xcode installed.
- Xcode version capable of building the project and an iOS 16+ SDK.
- iPhone running iOS 16.0 or later, or a compatible iOS Simulator.
- An Apple Developer Team when installing directly to a physical device through Xcode.

## Build Locally

1. Clone the repository.

   ```bash
   git clone https://github.com/iamgasgass/OldSafari.git
   cd OldSafari
   ```

2. Open the Xcode project.

   ```bash
   open OldSafari/OldSafari.xcodeproj
   ```

3. In Xcode, choose an iPhone or simulator as the run destination.

4. For a physical device build, select your Apple Developer Team under **Signing & Capabilities**.

5. Build with `Command-B`, run with `Command-R`, or choose **Product > Archive** to create an archive.

> The deployment target is iOS 16.0+.

## Unsigned IPA via GitHub Actions

The repository includes `.github/workflows/build.yml`. It runs on pushes to `main` or `master` and can also be started manually through `workflow_dispatch` in the Actions tab.

The workflow:

1. Builds with `CODE_SIGNING_ALLOWED=NO`; an Apple Developer account is not required for this build stage.
2. Places `OldSafari.app` inside `Payload/`.
3. Packages the payload as `OldSafari-Unsigned.ipa`.
4. Uploads the IPA and the build log as workflow artifacts.

### Install the Artifact

1. Open the completed GitHub Actions run.
2. Download the `OldSafari-Unsigned-IPA` artifact.
3. Sign it with your own installation method, such as AltStore, Sideloadly, Xcode, or a personal provisioning profile.
4. Install the signed IPA on your device.

Unsigned artifacts are build outputs, not installable iOS applications until they are signed with an appropriate certificate and provisioning profile.

## Project Principles

- **Visual preservation:** New work should retain the characteristic OldOS / classic Safari visual language.
- **Native behaviour:** Browser features should be implemented with supported iOS and WebKit APIs whenever possible.
- **Modern-device awareness:** The layout should remain correct around the status bar, notch, Dynamic Island, and home indicator.
- **Private-mode consistency:** Any relevant UI or data flow should be evaluated for both normal and Private Browsing modes.
- **Responsive feedback:** Toolbar actions and tab closing should continue to provide haptic feedback where appropriate.

## Manual Verification

Before submitting a change, verify the relevant flows on at least one compatible simulator or physical device.

- Navigate backward and forward across multiple pages.
- Confirm the reload/stop control and progress bar follow load state.
- Confirm the HTTPS lock appears for HTTPS destinations.
- Create, switch, and close several tabs.
- Validate normal and private tab behaviour separately.
- Add, edit, remove, and open bookmarks.
- Check history grouping, single-entry deletion, and Clear History confirmation.
- Test Find on Page and Request Desktop Website.
- Verify `tel:`, `mailto:`, and `maps:` links leave the web view and are handed to iOS.
- Check the share sheet and Copy Link action.
- Inspect the layout on a notched / Dynamic Island device profile.
- Trigger a real file download (a direct `.ipa`, `.zip`, or `.pdf` link) and confirm the confirmation alert, live progress, and completed Open/Share/Delete actions all work, including after relaunching the app.
- Open a link with `target="_blank"` or a `window.open()`-driven download button and confirm the new tab is created, brought to the foreground automatically, and actually loads — not left blank.
- Trigger a page's `alert()`, `confirm()`, and `prompt()` and confirm the custom iOS 6 styled panel appears instead of the system alert.
- Long-press a link and an image to confirm the context menu actions, including Save Image to Photos.
- Toggle Reader Mode on an article-like page and confirm the Content Blocker switch persists across a relaunch.

## Contributing

Contributions are welcome, especially fixes that improve fidelity, stability, WebKit behaviour, or compatibility with supported iOS releases.

1. Fork the repository and create a feature branch.

   ```bash
   git checkout -b feature/your-change
   ```

2. Keep the implementation focused and preserve the established UI language.
3. Test the affected flows in normal and Private Browsing modes when applicable.
4. Commit with a clear message and open a pull request describing the change and how it was tested.

When filing an issue, include the iPhone or simulator model, iOS version, reproducible steps, expected and actual behaviour, and screenshots or logs when useful.

## License and Attribution

OldSafari is a standalone rebuild derived from the Safari app in **The OldOS Project** v2.0.8. The original project is by [@zzanehip](https://github.com/zzanehip) and is licensed under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

- Original project: [zzanehip/The-OldOS-Project](https://github.com/zzanehip/The-OldOS-Project)
- Original author: [@zzanehip](https://github.com/zzanehip)
- License: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

Redistributions and adaptations must preserve appropriate attribution to the original author, identify modifications where required, and include a link to the CC BY 4.0 license.

Suggested attribution:

```text
OldSafari is based on the Safari implementation from The OldOS Project
by @zzanehip, licensed under CC BY 4.0.
Original project: https://github.com/zzanehip/The-OldOS-Project
```

## Disclaimer

OldSafari is an independent, unofficial project. It is not affiliated with, endorsed by, sponsored by, or associated with Apple Inc. Safari and iOS are trademarks of Apple Inc.

## Support

- Repository: [iamgasgass/OldSafari](https://github.com/iamgasgass/OldSafari)
- Bug reports and feature requests: [GitHub Issues](https://github.com/iamgasgass/OldSafari/issues)

---

Built for people who ❤️ and miss the character of classic iOS, without giving up the browser features expected on modern iPhones.

- Built by [@iamgasgass] (https://github.com/iamgasgass)
