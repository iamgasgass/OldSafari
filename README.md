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
A dual-field title bar: address field plus a separate Google search capsule.
- Full in-app **Downloads manager** with progress, Files integration and share.
- **Reader Mode** with automatic article detection.
- Unified local library for bookmarks and browsing history.
- An extended page-actions sheet: Reading List, Save PDF, Print, Mail Link, and more.
- Rich long-press interactions on navigation controls and in-page links.
- Session restore across launches, up to 8 tabs per browsing mode.
- Proper handoff of external schemes such as `tel:`, `mailto:`, and `maps:` to iOS.
- An unsigned IPA build workflow for GitHub Actions.

## Interface Fidelity

### Safari Chrome

OldSafari recreates the distinctive hardware-like appearance of classic Safari rather than replacing it with contemporary flat UI.

- Dual-intensity metallic gradients on the navigation bar and bottom toolbar.
- Brushed blue-grey finish in normal browsing mode.
- Rounded, glossy address field with an integrated loading indicator that sweeps in as a hard-edged progress plate, matching the original iOS 6 treatment.
- A separate glossy Google search capsule sitting alongside the address field, each expanding to fill the row while being edited and yielding to a sliding Cancel button.
- Physical-style controls with rounded contours, inner shadows, and glass-like reflections.
- Classic back, forward, action, bookmarks, and tab-count toolbar controls.
- A red badge on the action (share) icon whenever a download is in progress.
- OldOS-derived Safari icon assets retained in `Assets.xcassets/Safari Icons`.

### Private Appearance

Private Browsing has a complete dark visual treatment rather than a simple tint change.

- Charcoal and midnight-blue metallic bars.
- Dark forms and lists that retain the same skeuomorphic language.
- A dedicated private-mode explainer for new private tabs.
- A direct control in the tab manager to enter or switch browsing mode.
- Private tabs use a non-persistent `WKWebsiteDataStore` and are never written to the restored session or to History.

## Browser Capabilities

### Navigation

| Capability | Behaviour |
|---|---|
| Back and Forward | Uses the current web view's navigation history. |
| Long-Press History Preview | Long-pressing Back or Forward pops up a list of recent pages in that direction (from `WKBackForwardList`), tap to jump straight to one. |
| Reload and Stop | A single inline address-bar control changes according to loading state. |
| Loading Progress | A glossy blue progress bar is rendered inside the URL-field rectangle. |
| HTTPS Indicator | A lock indicator is shown for secure HTTPS destinations. |
| Address Entry | A dedicated address field with URL-aware keyboard and autofill hints. |
| Smart Go Heuristics | Typed text is routed automatically: an explicit `http(s)://` loads as-is, text containing a space or no dot is sent to search, anything else is promoted to `https://`. |
| Google Search Field | A second, independent capsule field next to the address bar submits directly to Google search. |
| Desktop Website | Requests the desktop version of a site by swapping the WebKit user agent, then reloads. |
| Reader Mode | Automatically detects article-like pages and offers an "Aa" glyph in the title bar to strip a page down to a clean, readable layout (light and dark variants). |
| Find on Page | Uses the native iOS 16 find interaction to search page content. |
| Pull to Refresh | Standard `UIRefreshControl` pull-down gesture reloads the current page. |
| JavaScript Panels | `alert`, `confirm`, and `prompt` dialogs from web content are rendered as native iOS alerts. |
| New-Window Handling | Links using `target="_blank"` or `window.open` open in a new page instead of being silently dropped. |
| External Schemes | Any non-web scheme (`tel:`, `mailto:`, `maps:`, `facetime:`, App Store links, etc.) is handed off to iOS; only `http`, `https`, `about`, `blob`, `data`, and `file` stay inside the web view. |
| Full-Screen Layout | Chrome extends behind the status-bar and Dynamic Island area, following modern Safari conventions. |

### Downloads

OldSafari ships a complete download manager, not just a pass-through to the system.

| Capability | Behaviour |
|---|---|
| Automatic Capture | Any response the browser cannot render inline â `Content-Disposition: attachment`, unsupported MIME types, `application/octet-stream`, archives, media attachments â is redirected into `WKDownload` automatically. |
| Blob / JS Downloads | A lightweight JavaScript bridge captures `URL.createObjectURL` downloads (e.g. Google Drive exports, GitHub archive links) that WebKit would otherwise ignore, and turns them into real files. |
| Live Progress | Each entry shows a live byte-progress bar and a "x of y" status line, fed by KVO on the underlying `Progress` object. |
| Downloads Sheet | An iOS 6-styled sheet lists every download, running or finished, with Cancel, Open in Files, Share, and Delete actions per row, plus a "Clear Finished" sweep. |
| Toolbar Badge | The action (share) button shows a red count badge while downloads are running. |
| Quick Access | Long-pressing the action button jumps straight to the Downloads sheet; it also opens automatically the first time a download starts. |
| Files Integration | Completed downloads live under the app's `Documents/Downloads` folder and can be revealed directly in the Files app. |

### Tabs

| Capability | Behaviour |
|---|---|
| Multiple Tabs | Maintains multiple browser tabs through a central tab store, up to 8 per browsing mode. |
| Active Tab State | Keeps the active tab, title, URL, load state, and navigation state synchronised with the UI. |
| Cover-Flow Tab Switcher | Presents open tabs as live, swipeable cards that shrink to the classic OldOS proportions, with neighbouring pages peeking in at reduced opacity â not a static thumbnail grid. |
| Tab Count | Displays the current tab count through the classic Safari tab-count control. |
| New Tabs | Opens blank tabs on a Favorites start page. |
| Close Tabs | Supports tab closing with tactile feedback; closing the last tab of a mode replaces it with a fresh blank one. |
| Page Actions Menu | Long-pressing the tab-count button opens a sheet with New Page, Close This Page, and Close All Pages. |
| Session Restore | Up to 8 non-private tabs are restored between app launches; restored tabs defer their network request until actually shown, so a cold launch with several saved pages costs a single request. |
| Private Tabs | Supports Private Browsing alongside the normal browsing experience, with its own tab pool. |

### Bookmarks and History

OldSafari includes a locally managed library with a shared iOS-style presentation.

| Capability | Behaviour |
|---|---|
| Unified Library | Bookmarks and History share one sheet, selected with a bottom segmented switch. |
| Add Bookmark | Saves the active page to local bookmarks via a dedicated add sheet with an editable title. |
| Edit Bookmark | Allows bookmark titles to be renamed in place. |
| Remove Bookmark | Uses the original red removal glyph for delete actions. |
| History Logging | Stores browsing history locally; private browsing never writes to it. |
| History Grouping | Groups entries into Today, Yesterday, and dated sections. |
| Swipe to Delete | Deletes individual history entries by swiping. |
| Clear History | Provides a confirmation flow before clearing all history. |
| Library Styling | Uses an iOS-era fabric/background finish and a glossy blue Done button. |

### Page Actions Sheet

Long-pressing links, or tapping the action button, surfaces a full iOS-6-styled action sheet that mirrors what current Safari offers, only rows that are actually relevant to the page are shown:

- Add Bookmark, with an inline title/URL editor.
- Add to Reading List, using the system Safari Reading List so items resurface in real Safari too.
- Add to Home Screen (hands the page to system Safari to finish, since only it can pin a web clip).
- Mail Link to this Page, opening a pre-filled `mailto:` draft.
- Copy, placing the current URL on the pasteboard.
- Show/Hide Reader, when the current page qualifies.
- Find on Page.
- Request Desktop Site / Request Mobile Site, toggled per tab.
- Save PDF to Files, rendering the live page to PDF via `WKWebView.createPDF` and offering the system document picker.
- Downloads, showing the active download count when any are running.
- Shareâ¦, opening the native iOS share sheet (AirDrop, Messages, installed extensions).
- Print, using `UIPrintInteractionController` for AirPrint.

### In-Page Link Interactions

Long-pressing a link inside a loaded page opens a native context menu with:

- Open, Open in New Page
- Copy Link
- Download Linked File
- Shareâ¦

## Architecture

The codebase is organised around a small set of app-specific models, two central stores, SwiftUI screens, and WebKit integration.

```text
OldSafari/
âââ .github/
â   âââ workflows/
â       âââ build.yml                  # GitHub Actions unsigned IPA build
âââ OldSafari.xcodeproj/               # Xcode project
âââ OldSafari/
â   âââ OldSafariApp.swift             # Application entry point
â   âââ Models/
â   â   âââ SafariTab.swift            # WKWebView wrapper: nav state, Reader Mode, blob-download shim
â   â   âââ SafariBookmark.swift
â   â   âââ SafariHistoryEntry.swift
â   â   âââ SafariDownload.swift       # One tracked download and its progress/state
â   âââ Store/
â   â   âââ SafariTabStore.swift       # Tabs, bookmarks, history, private mode, session restore
â   â   âââ SafariDownloadManager.swift# WKDownloadDelegate, download queue, filesystem
â   âââ Views/                         # Browser chrome, web view, library, tab switcher, downloads,
â   â                                   # search fields, start page, share/page-actions sheet
â   âââ Support/                       # Shared colour palette, OldOS UI kit, notification names
â   âââ Assets.xcassets/               # Original OldOS Safari assets and app icon
âââ README.md
âââ LICENSE
```

### State Model

`SafariTabStore` is the central owner of browser-facing app state, including tabs, the selected tab, bookmarks, history, and Private Browsing state. `SafariDownloadManager` is a parallel singleton store dedicated to the download queue, acting as the app's `WKDownloadDelegate`. Views render that state and send user actions back to the stores, avoiding independent copies of browser data across the interface.

Each browser tab is represented by a `SafariTab`, which owns its own `WKWebView`, tracks Reader-Mode availability, and injects the blob-download bridge script. Bookmark, history, and download data are represented by `SafariBookmark`, `SafariHistoryEntry`, and `SafariDownload`, respectively. The app uses Combine together with observation of `WKWebView` and `Progress` properties to reflect loading, title, URL, navigation, and download progress reactively rather than through timed polling.

## Technology

| Area | Technology |
|---|---|
| Language | Swift |
| User Interface | SwiftUI |
| Browser Engine | WebKit / `WKWebView`, `WKDownload` |
| Reactive State | Combine and `WKWebView` / `Progress` KVO |
| Application Pattern | Models, two central Stores, and SwiftUI Views |
| System Integration | AirPrint, Files, Photos, system Reading List, native Share Sheet |
| Target Platform | iPhone on iOS 16.0+ |
| CI Build | GitHub Actions |

OldSafari relies on Apple platform frameworks for its primary UI, browser, download, sharing, printing, haptic, and system-integration behaviour.

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
- **System appearance passthrough:** Page content and every system-provided control (keyboard, alerts, share sheet, context menus, status bar) must always follow the device's own Light/Dark Mode setting, in both Normal and Private Browsing â only the custom chrome is themed.
- **Responsive feedback:** Toolbar actions and tab closing should continue to provide haptic feedback where appropriate.

## Manual Verification

Before submitting a change, verify the relevant flows on at least one compatible simulator or physical device.

- Navigate backward and forward across multiple pages; check the long-press history preview on both arrows.
- Confirm the reload/stop control and progress bar follow load state.
- Confirm the HTTPS lock appears for HTTPS destinations.
- Create, switch, and close several tabs, and confirm the cover-flow switcher, the 8-tab cap, and Close All Pages.
- Validate normal and private tab behaviour separately, including session restore after relaunch.
- Add, edit, remove, and open bookmarks.
- Check history grouping, single-entry deletion, and Clear History confirmation.
- Test Find on Page, Reader Mode, and Request Desktop/Mobile Site.
- Trigger a real download (attachment link) and a blob/JS-based download; confirm progress, Cancel, Open in Files, Share, and the toolbar badge.
- Exercise the page-actions sheet: Reading List, Add to Home Screen, Mail Link, Save PDF to Files, Print.
- Long-press a link in a loaded page and confirm Open / Open in New Page / Copy Link / Download / Share.
- Verify `tel:`, `mailto:`, `maps:`, and other non-web schemes leave the web view and are handed to iOS.
- Inspect the layout on a notched / Dynamic Island device profile.

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

OldSafari's own source code is licensed under the **MIT License** (see `LICENSE`).

The project is a standalone rebuild derived from the Safari app in **The OldOS Project** v2.0.8. The original project is by [@zzanehip](https://github.com/zzanehip) and is licensed under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/). Because this app is an adaptation of that work, the CC BY 4.0 attribution requirement continues to apply to the OldOS-derived visual assets and design language, independently of the MIT license covering this repository's code.

- Original project: [zzanehip/The-OldOS-Project](https://github.com/zzanehip/The-OldOS-Project)
- Original author: [@zzanehip](https://github.com/zzanehip)
- Original license: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- This repository's license: MIT (see `LICENSE`)

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

Built for people who miss the character of classic iOS, without giving up the browser features expected on modern iPhones.
