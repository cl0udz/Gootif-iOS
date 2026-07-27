# Gootif iOS

SwiftUI iPhone client for [Gootif](https://github.com/cl0udz/Gootif) — a
self-hosted notification hub where home-lab services and scheduled Claude
agents post alerts and rich structured reports.

Tabs: **Recent** (latest notifications, grouped by service), **Services**
(per-service history), **Settings** (API key override). Notifications whose
`metadata` carries a `kind` + `payload` get a native report renderer
(`news_feed`, `task_digest`, `security_feed` — see the server repo's
`agents/REPORTS.md`); everything else falls back to a generic detail view.

Sibling clients: [Gootif-MacOS](https://github.com/cl0udz/Gootif-MacOS),
[Gootif-Windows](https://github.com/cl0udz/Gootif-Windows).

## Build

Requires Xcode 16+ / iOS 18 SDK.

```bash
brew install xcodegen
cp Gootif/Services/Secrets.swift.example Gootif/Services/Secrets.swift
# edit Secrets.swift: set the APP_KEY from your server's config.php
xcodegen generate
open Gootif.xcodeproj
```

The server base URL lives in `Gootif/Services/APIClient.swift`; the API key
can also be overridden at runtime in the app's Settings tab.

## Layout

| Path | What it is |
|------|------------|
| `Gootif/App/` | App entry point and assets |
| `Gootif/Models/` | API models + report payload models (`Report.swift`, `ReportBlock.swift`) |
| `Gootif/Services/` | `APIClient` (server API), `AppSettings`, `Secrets` (gitignored) |
| `Gootif/Views/` | SwiftUI views: Recent, Services, Settings, report renderers, shared `DesignSystem.swift` |
| `project.yml` | xcodegen spec — the `.xcodeproj` is generated, not tracked |
