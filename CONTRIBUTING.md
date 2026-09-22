# Contributing to Apex Dash

Thanks for helping. Apex Dash is a free, open source dashboard for sim racing
games, and it grows through contributions: new games, new dashboards, new
languages and fixes.

## Before you start

- **Sign the CLA.** The first time you open a pull request, a bot asks you to
  comment once to accept the [Contributor License Agreement](CLA.md). You keep
  the copyright in your work; the CLA lets the maintainer ship it on the App
  Store as well as under the GPL.
- **Open an issue first** for anything bigger than a small fix, so we can agree
  on the approach before you spend time on it.
- **Forks keep their own name and icon.** See [TRADEMARKS.md](TRADEMARKS.md).

## Build and run

Requirements: Xcode 16 or later, iOS 17 or later, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open ApexDash.xcodeproj
```

You do not need the game. Either:

- turn on **Settings › Demo drive** in the app, or
- run the simulator script against the iOS Simulator or a device:

```bash
python3 Tools/f1_sim.py 127.0.0.1                 # Simulator, F1 26 layout
python3 Tools/f1_sim.py 127.0.0.1 --format=2025   # F1 25 layout
python3 Tools/f1_sim.py 192.168.1.42              # a phone on your network
```

Run the tests before opening a pull request:

```bash
xcodebuild test -project ApexDash.xcodeproj -scheme ApexDash \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Useful launch arguments (Scheme › Run › Arguments):

| Argument | Effect |
| --- | --- |
| `-startDemo YES` | Starts the demo drive at launch |
| `-skipHome YES` | Opens the full-screen dashboard instead of the menu |
| `-dashTheme cluster` | Picks a dashboard |
| `-forceOnboarding YES` | Shows the onboarding again |
| `-onboardingPage 2` | Opens the onboarding at a given scene |
| `-showSettings YES`, `-showLaps YES`, `-showWebGuide YES` | Opens a screen |
| `-menuTour YES` | Walks through the menu on its own, for recordings |
| `-appLanguage tr` | Forces a language |

## Working with an AI assistant

`.claude/skills/apex-dash/SKILL.md` describes the architecture, the conventions
and the recipes below in a form an assistant can follow. Claude Code picks it up
automatically inside the repository; for other tools, paste the file in.

## How the app is organised

```
Sources/
  Telemetry/        Game-independent core
    TelemetryClient   UDP listener; hands datagrams to the active game
    TelemetryGame     The protocol every game implements
    DashboardModel    What every dashboard draws
    LapTiming         Best lap, sector colours, live delta
    LapTrace          20 Hz lap traces for the analysis page
    LocalAnalysisServer  Serves the analysis page to browsers on the Wi-Fi
    SitePairing       Finds the phone from apexdash.pro (via ntfy.sh)
  Games/
    F1/             EA SPORTS F1 25 and F1 26
  UI/               Dashboards, menu, onboarding, settings
Resources/
  Localizable.xcstrings   All app text, per language
Web/                The analysis page (also bundled into the app)
Tools/              Telemetry simulator
Tests/
```

Data flows one way: **game → UDP → `TelemetryClient` → `TelemetryGame` →
`DashboardModel` → dashboards**. Dashboards never know which game is running.

## Adding a game

Read [docs/ADDING_A_GAME.md](docs/ADDING_A_GAME.md). In short: one folder under
`Sources/Games/`, one class that turns datagrams into `DashboardModel` values,
and tests built from the game's published packet specification.

## Adding a language

All text lives in `Resources/Localizable.xcstrings` and
`Resources/InfoPlist.xcstrings` (permission prompts).

1. Open the project in Xcode and select `Localizable.xcstrings`.
2. Click **+** at the bottom of the language list and add your language.
3. Translate every row. Keep placeholders such as `%1$@` exactly as they are;
   their order in the sentence may change.
4. Do the same in `InfoPlist.xcstrings`.
5. Add the language code to `CFBundleLocalizations` in `project.yml`.
6. Run the tests. `LocalizationTests` fails if a key or placeholder is missing.

The new language appears in **Settings › Language** automatically. Dashboard
labels such as KPH, FUEL and LAP stay in English, as on real wheel displays.

The analysis page (`Web/index.html`) has its own small text table near the top
of its script.

## Adding a dashboard

1. Add a case to `DashTheme` in `Sources/UI/Theme.swift`.
2. Create a view that takes a `DashboardModel` and a `unit` (the layout scale;
   size everything from it so the dashboard fits every screen).
3. Add it to `DashboardContent` and `DashboardBackground` in `HomeView.swift`,
   and give it a title in the String Catalog (`themeYourName`).
4. Check it in the demo drive, on a small iPhone and on an iPad.

Dashboards must be readable at a glance while driving: large numbers, strong
contrast, no text that only makes sense up close.

## Code style

- Write code that reads like the code around it.
- Comments in English. Explain why, not what.
- No third-party dependencies without discussing it in an issue first.
- Keep pull requests focused: one feature or fix each.

## Commit messages

A short summary line in the imperative ("Add Forza Motorsport telemetry"),
a blank line, then what changed and why.

## Reporting bugs

Use the bug report template. Include the game, platform (PC, PlayStation,
Xbox), the telemetry settings you use and the phone model.
