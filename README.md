# OldSafari

A standalone, modern-iOS-ready rebuild of the **Safari** app from
[The OldOS Project](https://github.com/zzanehip/The-OldOS-Project) (v2.0.8),
licensed by its original author under Creative Commons Attribution 4.0.

The goal: keep the exact OldOS Safari look — the brushed blue-grey chrome,
gloss address field, classic tab-count icon, bookmark/history glyphs — while
running natively full-screen on current iPhones and iOS, with the features
you'd expect from a modern browser.

## What's included

**Faithful to the original:**
- Brushed metal gradient toolbar and gloss address field, pixel-matched to the
  OldOS asset set (`Assets.xcassets/Safari Icons`)
- Classic back / forward / action / bookmarks / tab-count toolbar
- The same rounded address field with inline reload button

**Rebuilt from scratch as a modern app:**
- Full-screen edge-to-edge layout on every iPhone, chrome bleeding behind the
  status bar / Dynamic Island like modern Safari does
- Reactive tab model built on Combine + WKWebView KVO (no polling)
- Multiple tabs **and Private Browsing**, with a Safari-style tab-switcher grid
- Loading progress bar, HTTPS lock indicator, stop/reload toggle
- Request Desktop Website, Find on Page (native iOS 16 find interaction)
- Unified Library sheet: Bookmarks + History with a bottom segmented switch,
  bookmark add/edit with the original red "remove" glyph, grouped history
  (Today / Yesterday / date) with swipe-to-delete and Clear History
  confirmation
- A Favorites start page for blank tabs, plus a proper Private Browsing
  explainer screen
- System schemes (`tel:`, `mailto:`, `maps:`, etc.) are handed off to iOS
  instead of failing inside the web view
- Haptic feedback on toolbar actions and tab close
- iOS share sheet

## Project layout

```
OldSafari/OldSafari/
├── OldSafariApp.swift          # App entry point
├── Models/                     # SafariTab, SafariBookmark, SafariHistoryEntry
├── Store/                      # SafariTabStore (tabs, bookmarks, history, private mode)
├── Views/                      # Address bar, toolbar, tabs grid, library, web view, start page
├── Support/                    # Shared color palette + notification names
└── Assets.xcassets/            # Original OldOS Safari icon set + app icon
```

## Build locally

1. Open `OldSafari/OldSafari.xcodeproj` in Xcode on a Mac.
2. Select your iPhone (or a simulator) as the run destination.
3. Set your Apple Developer Team under **Signing & Capabilities** if you plan
   to run on-device without CI.
4. Build or Archive.

Deployment target: iOS 16.0+.

## Build an unsigned IPA via GitHub Actions

Push this repo to GitHub (or fork it) — `.github/workflows/build.yml` builds
an **unsigned** IPA automatically on every push to `main`/`master`, and can
also be triggered manually from the Actions tab (`workflow_dispatch`).

The workflow:
1. Builds the app with `CODE_SIGNING_ALLOWED=NO` (no Apple Developer account
   needed).
2. Packages `OldSafari.app` into `Payload/` and zips it as
   `OldSafari-Unsigned.ipa`.
3. Uploads the IPA (and the full build log) as workflow artifacts.

Download the `OldSafari-Unsigned-IPA` artifact from the completed run, then
sign it with your own tooling (AltStore, Sideloadly, a personal provisioning
profile, etc.) to install it on a device.

## License / attribution

OldOS is licensed by its author under Creative Commons Attribution 4.0.
Original project: https://github.com/zzanehip/The-OldOS-Project

This rebuild is intended to retain attribution to the original author.
