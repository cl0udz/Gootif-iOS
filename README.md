# Gootif iOS

SwiftUI iPhone and iPad client for [Gootif](https://github.com/cl0udz/Gootif) — a
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

## Apple push notifications

The app registers with APNs and uploads its installation ID/device token to
`POST /api/devices`. Settings shows registration status, retry, and opt-out.
Failed uploads retry with backoff while the app runs and on the next activation.
Allow notifications after launching the newly signed app once.

Push requires the App ID's Push Notifications capability, a matching provisioning
profile and the server's APNs configuration/worker. Run `xcodegen generate` after
updating `project.yml`. Debug selects `APNS_ENVIRONMENT=development`; Release
selects `production`. For a development-signed Release build, explicitly override
that setting. Exported production builds must have a production APNs entitlement.
The signed environment takes precedence over the build's fallback setting.

Deploy the backend before upgrading clients. See the server repository's
[deployment guide](https://github.com/cl0udz/Gootif/blob/main/DEPLOYMENT.md#native-ios-and-macos-push-apns)
for private key setup and real-device verification. Simulator/unsigned build
success alone does not verify delivery through Apple's servers.

## Adaptive interface

The target supports both iPhone and iPad, including landscape and iPad multitasking.
Regular-width windows show a notification browser beside the selected report;
compact windows use tabs and native drill-down navigation with a Back button. Service navigation and
selected notifications stay in one navigation hierarchy across these layouts. Reports use a
760-point reading measure and Settings uses 640 points. Tables fall back to labeled
records when columns cannot fit; notification metadata stacks at accessibility
text sizes. Refresh is available through pull-to-refresh, the toolbar, or Command-R.

For reproducible offline visual review, launch a Debug build with
`-layoutPreview -openLatestReport`. This seeds Recent with a sample report and an
alert and skips push registration. Omit `-openLatestReport` to inspect the list.
Add `-longReport` for an 18-section reading-continuity fixture. Services history
also uses offline data in this mode. The fixture flag is excluded from Release builds.

Device review checklist: iPhone portrait/landscape; iPad portrait/landscape;
iPad narrow multitasking window; accessibility text sizes; light/dark appearance;
selecting multiple notifications; Services navigation; returning from and deleting a
detail; push deep links. Real-device push delivery still requires the APNs setup above.

### iPhone Duo

Use Xcode 27.1 or later and its Duo runtime for device-specific validation.
The app and UI tests build with Xcode 27.1 (27A9275) / iOS 27.1 SDK. The app uses a persistent `NavigationSplitView` on both size
classes instead of replacing the browser with a modal when the display changes.
Native containers manage compact navigation, fold-aware columns, safe areas, and
vertical bars. Column widths are not capped, allowing the system to balance panes
around the hinge. Toolbar actions include titles and symbols for vertical bars.
Continuous report content remains in a ScrollView rather than being relocated
into an arrangement when the device partially folds.

Duo simulator review (2026-10-21, iOS 27.1 / 24A94232): visually checked the
closed outer display, open inner display, and partially open book pose. The same
selected report transitions from a single column to two columns; the system
balances columns around the hinge. The report table falls back to labeled records
in narrow panes and displays columns when space permits. Native navigation and
tabs use the side rail on the outer display.

UI regression coverage includes selecting a report, rotating both ways, changing
selection in the expanded layout, and Back/reselect in compact layout. Tests use
the actual visible layout, since Duo remains a phone even with two columns, and
recognize its side-rail `BackButton` independently of the standard top bar.

Duo rotation tests also verify that a middle section of a long report stays visible
and an unsaved Settings draft survives orientation changes. Reading anchors use
content identities; report blocks use their stable position within the immutable
payload instead of a new UUID on every render.

`FoldContinuityTests` is an opt-in Device Hub test. Create `Documents/enable-fold-review`
in the test runner container, run that class, read `Documents/requested-pose`,
apply the indicated pose in Device Hub, then create the matching file in Documents
to acknowledge it. The test checks the visible reading section and draft after
each open / partially open / closed transition. Remove the enable file afterwards.
Duo fold continuity passed on 2026-10-21: the same middle report section and
unsaved Settings draft survive open, partially open, and closed transitions.
Report feeds use stable lazy scroll targets so width changes preserve the current
article instead of jumping to the next one. iPad Pro 11-inch (iPadOS 27.0) UI regression passed for selection/reselection,
portrait/landscape reading continuity, unsaved Settings drafts, and service-history
navigation across tab changes. The system-window resize test also passed: dragging
the lower-right corner reduces the window width while retaining the selected
report and its actions. No claim of physical-device validation is made.

References: [Apple preparation guide](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
and [Duo design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo).

Run the offline navigation regression on an installed simulator:

```bash
xcodegen generate
xcodebuild -project Gootif.xcodeproj -scheme Gootif \
  -destination 'platform=iOS Simulator,name=Gootif iPhone Layout' \
  CODE_SIGNING_ALLOWED=NO test
```

Repeat with `name=Gootif iPad Layout`. The UI test checks selection through rotation,
Back/reselect on compact devices, and changing the selected item in a split view.
For Duo, select `name=Gootif Duo Verified` and use Device Hub's Closed / Partially
Open / Open controls before running the test. Pose changes are manual; XCTest
covers navigation and rotation within the selected pose.
