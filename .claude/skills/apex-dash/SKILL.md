---
name: apex-dash
description: How Apex Dash is built and where it is going - architecture, conventions, and step-by-step recipes for adding a racing game, a dashboard or a language. Use when working in the ApexDash repository, or when planning a contribution to it.
---

# Working on Apex Dash

Apex Dash turns an iPhone or iPad into the steering wheel display of a racing
game, and serves a lap analysis page to browsers on the same Wi-Fi. It is free
software (GPLv3), published on the App Store by its maintainer, and built to
grow through contributions.

Read this before changing code. It is the shape of the project, not a tutorial.

## What the project is trying to be

1. **A display you trust at 200 km/h.** Big numbers, strong contrast, no
   decoration that costs legibility. If a change makes something harder to read
   in a corner, it is the wrong change.
2. **Local first.** Telemetry goes from the game to the phone, and from the
   phone to your browser. No accounts, no analytics, no servers holding user
   data. New features must keep that true.
3. **More games, same dashboards.** Dashboards draw a shared model. Adding a
   game must not require touching dashboards.
4. **Free, and pleasant to contribute to.** No paid tiers, no ads. Small,
   readable code with tests around the binary parsing.

Non-goals: setup tools for PC sim rigs, a social feed, cloud storage of laps,
anything that needs a login.

## Architecture

```
game ──UDP──▶ TelemetryClient ──▶ TelemetryGame ──▶ DashboardModel ──▶ dashboards
                    │                                      │
                    │                                      └─▶ LapTiming, LapTrace
                    └─▶ LocalAnalysisServer ──HTTP──▶ browser on the same Wi-Fi
```

| Path | What lives there |
| --- | --- |
| `Sources/Telemetry/TelemetryClient.swift` | UDP listener, connection status, demo drive control. Implements `TelemetrySink`. |
| `Sources/Telemetry/TelemetryGame.swift` | The protocol a game implements, plus `TelemetrySink` and `TelemetryDemo`. |
| `Sources/Telemetry/DashboardModel.swift` | Everything a dashboard can draw. Game-independent. |
| `Sources/Telemetry/LapTiming.swift` | Best lap, sector colours, live delta, completed laps. Fed with plain numbers, not packets. |
| `Sources/Telemetry/LapTrace.swift` | 20 Hz lap traces and their JSON for the analysis page. |
| `Sources/Telemetry/LocalAnalysisServer.swift` | Small HTTP server on port 8777 serving the bundled page and lap JSON. |
| `Sources/Telemetry/SitePairing.swift` | Announces the phone's local address to an ntfy.sh topic so apexdash.pro can hand the browser over. |
| `Sources/Telemetry/ByteReader.swift`, `ByteWriter.swift` | Little-endian binary reading and writing. |
| `Sources/Games/F1/` | F1 25 / F1 26: packets, decoder, trace recorder, demo drive. The reference implementation. |
| `Sources/UI/` | Dashboards, menu carousel, onboarding, settings, splash. |
| `Resources/Localizable.xcstrings` | Every piece of user-facing text. |
| `Web/index.html` | The analysis page; bundled into the app and deployed to apexdash.pro. |
| `Tools/f1_sim.py` | The same simulation as the in-app demo, over real UDP. |

Rules that keep this working:

- **Dashboards never parse packets** and never know which game is connected.
  They read `DashboardModel` and its computed labels (`boostLabel`,
  `aeroLabel`, …), which already account for game differences.
- **Games never touch SwiftUI.** A `TelemetryGame` decodes bytes and writes
  through `TelemetrySink`.
- **The model is one way.** Nothing writes back into the game.
- **Sizes scale from `unit`.** Every view takes a `unit` (derived from the
  screen's shorter side) and expresses sizes as multiples of it, so one layout
  fits every device. Never hard-code points.

## Conventions

- Swift 5, iOS 17, SwiftUI, no third-party dependencies. Adding one needs a
  discussion in an issue first.
- The Xcode project is generated: edit `project.yml`, then `xcodegen generate`.
- Comments in English, explaining why. Match the density of the file you are in.
- User-facing text goes in `Resources/Localizable.xcstrings` with every existing
  language filled in; `Strings.text("key")` reads it. Dashboard labels (KPH,
  FUEL, LAP) stay in English on purpose.
- Colours: `Palette` for the app's chrome; dashboards use their own palettes,
  where colour carries meaning (temperature, flags, sectors).
- `Typeface` (Saira) for menus and settings. Dashboards use the system font:
  their layouts are measured against its metrics.
- Commits: imperative summary line, then what changed and why.

## Testing and running without the game

```bash
xcodebuild test -project ApexDash.xcodeproj -scheme ApexDash \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

- `PacketParsingTests` builds packets byte by byte for both F1 formats.
- `DemoDriveTests` drives the built-in simulation through the real decoder and
  asserts laps, sectors, traces and top speed come out.
- `LocalizationTests` fails when a language misses a key or a placeholder.

Launch arguments (Scheme › Run › Arguments, or `xcrun simctl launch`):

| Argument | Effect |
| --- | --- |
| `-startDemo YES` | Start the demo drive at launch |
| `-skipHome YES` | Open full screen instead of the menu |
| `-dashTheme cluster` | Choose a dashboard |
| `-showSettings YES`, `-showLaps YES`, `-showWebGuide YES` | Open a screen |
| `-forceOnboarding YES`, `-onboardingPage 3` | Replay the onboarding |
| `-menuTour YES` | Walk through the menu on its own, for recordings |
| `-appLanguage en` | Force a language |

The analysis page also accepts `?lang=en` / `?lang=tr`.

## Recipe: add a racing game

Full version in `docs/ADDING_A_GAME.md`. The shape:

1. `Sources/Games/<Game>/` with packet structs parsed through `ByteReader`.
2. A class conforming to `TelemetryGame`: `consume(_:sink:)` decodes one
   datagram and returns `false` when it is not this game's; `reset()` clears
   session state; `tick(sink:)` handles time-based clean-up; `makeDemo()`
   optionally returns a simulated session.
3. Fill what the game provides; leave the rest at defaults. Compute
   `revLightsPercent` from RPM when the game has no shift lights. Set
   `SessionInfo.trackName` and publish laps through `LapTiming`, traces through
   `sink.publish(lapTraces:)`.
4. Tests built from the published specification, plus real captured datagrams if
   you have them.
5. Game selection is not built yet: `RootDashboardView` creates `F1Game`
   directly. The first second game should add the picker to the connection
   screen, storing `TelemetryGame.id`.

Good next targets: Forza Motorsport / Horizon (simple "Data Out" UDP), EA SPORTS
WRC, Assetto Corsa Competizione (needs a registration handshake), Gran Turismo 7
(encrypted, needs a heartbeat).

## Recipe: add a dashboard

1. New case in `DashTheme` (`Sources/UI/Theme.swift`).
2. A view taking `dash: DashboardModel` and `unit: CGFloat`.
3. Register it in `DashboardContent` and `DashboardBackground` in `HomeView.swift`.
4. Title key `themeYourName` in the String Catalog.
5. Check it with the demo drive, on a small iPhone and on an iPad, and in the
   menu carousel where it is drawn small.

Heavy drawing belongs in `Canvas`; the menu draws six dashboards at once.

## Recipe: add a language

1. Open `Resources/Localizable.xcstrings` in Xcode, add the language, translate
   every row, keep placeholders such as `%1$@` intact.
2. Same for `Resources/InfoPlist.xcstrings` (permission prompts).
3. Add the code to `CFBundleLocalizations` in `project.yml`.
4. `LocalizationTests` must pass. The language then appears in Settings on its
   own.

The analysis page keeps its own small text table at the top of its script.

## Things that bite

- **Menu performance.** The carousel draws several dashboards at once. Only the
  warming card runs at display rate; everything else is 10 Hz. Do not add
  per-frame work there.
- **Landscape only.** The app is landscape-locked; the splash counter-rotates
  when the phone is held upright. Any new full-screen view must handle that.
- **Safe areas.** Dashboards with their own housing (realistic, cluster) draw
  past the safe area on purpose; the others stay inside it.
- **Photosensitivity.** The shift flash and torch are guarded by a warning that
  must be confirmed. Do not add flashing effects without that gate, and respect
  `accessibilityReduceMotion`.
- **iOS and broadcast.** Receiving UDP broadcast needs an Apple entitlement, so
  the app asks players to send unicast to the phone's address. Do not "fix"
  this by enabling broadcast.
- **No app-side writes to apexdash.pro.** Pairing publishes one local address to
  ntfy.sh. Laps never leave the network.

## Licence, CLA and trademarks

- Code is GPLv3. Keep new files under the same licence.
- Pull requests need the [CLA](../../../CLA.md) signed once, because the
  maintainer also ships the app on the App Store.
- The name, logo and icon are not covered by the licence; forks rename. See
  `TRADEMARKS.md`.
- The app is not affiliated with Formula One, EA or Codemasters. Keep "F1" out
  of the app name, icon and store metadata; describing compatibility is fine.
