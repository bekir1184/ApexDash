# Apex Dash

An iPhone and iPad app that turns the phone into a racing game's steering wheel
display, and serves a lap analysis page to browsers on the same Wi-Fi.

**Start with the project skill: [`.claude/skills/apex-dash/SKILL.md`](.claude/skills/apex-dash/SKILL.md).**
It holds the architecture, the conventions and step-by-step recipes for adding a
game, a dashboard or a language. `CONTRIBUTING.md` covers the same ground for
people working without an assistant.

Quick rules:

- The Xcode project is generated. Edit `project.yml`, then run `xcodegen generate`.
- Comments and user-facing text in English; text goes in
  `Resources/Localizable.xcstrings`, never hard-coded in views.
- Dashboards read `DashboardModel` only; games decode packets only.
- Size everything from the `unit` a view is given, never in fixed points.
- No third-party dependencies without agreeing it in an issue first.
- Run the tests before proposing a change:

```bash
xcodebuild test -project ApexDash.xcodeproj -scheme ApexDash -destination 'platform=iOS Simulator,name=iPhone 16'
```
