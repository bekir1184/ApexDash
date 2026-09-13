# Apex Dash

Turns an iPhone into the steering wheel display of **F1 25** and **F1 26**.
It listens to the game's UDP telemetry output directly. No PC in the loop, no
server, no account, no ads, no tracking.

Free and open source under the MIT licence.

---

## What it does

Five dashboard themes, live at the game's send rate. Swipe sideways to change
theme, pull down for the menu.

| Theme | Look |
| --- | --- |
| `MODERN` | Bosch DDU style: high contrast, clean layout |
| `DOT MATRIX` | Real wheel LCD look; every shape resolves into LED dots |
| `REALISTIC` | A real F1 wheel display inside a bezel that carries the rev LEDs, with FIA flag clusters down both sides and a yellow LCD under pit limiter |
| `BROADCAST` | The blue TV halo HUD: round speed dial, BOOST and OVERTAKE, concentric RECHARGE / DEPLOY panels, BRAKE / THROTTLE slat blocks, battery, and a gear and rev strip along the bottom |
| `GAME` | A copy of the in-game cockpit wheel display |

Shown on every theme:

- 15 LED rev strip driven by `m_revLightsBitValue`; the whole screen flashes at
  the shift point, and the phone's flash can blink in sync if you enable it
- Gear, speed, RPM, throttle and brake
- Tyre surface and inner temperatures, brake disc temperatures, colour coded
- Lap time, delta to the car ahead, live delta to your own best lap, and
  sector times coloured against your best
- Start lights driven by the game's own `STLG` / `LGOT` events
- FIA flags, invalid lap warning, pit limiter
- **F1 26**: OVERTAKE (manual override) and ACTIVE AERO, because DRS is gone
- **F1 25**: DRS, in the same places

## Lap analysis in your browser

Finished laps upload themselves to <https://apexdash-app.vercel.app>. Open the
page, scan its QR code from the LAPS screen, and every lap you complete lands
there on its own.

Each lap carries a full 20 Hz trace: position, speed, throttle, brake, steering,
gear, RPM, ERS store and deployment, G forces. The page draws the track map
coloured by speed, pedals, ERS or sector, synchronised distance charts with a
shared cursor, lap-to-lap time delta, and a corner table with brake points,
entry, apex and exit speeds.

Sessions are keyed by a six character code and are deleted after 14 days.

## Game setup (Settings › Telemetry)

| Setting | Value |
| --- | --- |
| UDP Telemetry | On |
| UDP Broadcast Mode | **Off** |
| UDP IP Address | your iPhone's IP, shown in the app |
| UDP Port | 20777, changeable in the app |
| UDP Send Rate | 60 Hz |
| UDP Format | 2026 or 2025 |
| Your Telemetry | Public |

> **Why is broadcast off?** Since iOS 14, receiving broadcast or multicast
> traffic needs Apple's `com.apple.developer.networking.multicast` entitlement.
> Unicast straight to the phone's IP does not. Reserve the phone's address in
> your router so it stops changing.

## Photosensitivity

The shift warning flashes the screen rapidly, and can flash the phone's LED
too. The LED is **off by default** and a warning appears on first launch. If
you are sensitive to flashing light, leave both off.

## Packet layout

Verified against the official EA specifications: *Data Output from F1 25* and
the *2026 Season Pack Telemetry Output Structures*. The header is 29 bytes,
little endian, packed. Differences between the two games are collected in
`PacketFormat` and covered by tests.

| Packet | F1 25 | F1 26 |
| --- | --- | --- |
| Cars per packet | 22 | 24 |
| Car Telemetry (6) | 60 B per car, DRS byte, 16-bit engine temp | 59 B per car, 8-bit engine temp |
| Car Status (7) | 55 B per car | 59 B per car, adds ERS harvest limit per lap |
| Lap Data (2) | 57 B per car | 57 B per car |
| Participants (4) | 57 B per car, 8-bit ids | 60 B per car, 16-bit ids |
| Motion (0) | 60 B per car, float G forces | 54 B per car, quantised G forces |
| Car Telemetry 2 (16) | not sent | 10 B per car: active aero, overtake |

## Development

```bash
xcodegen generate          # writes ApexDash.xcodeproj
open ApexDash.xcodeproj
```

Fake telemetry, so you can work without the game running:

```bash
python3 Tools/f1_sim.py 127.0.0.1                 # Simulator, F1 26 layout
python3 Tools/f1_sim.py 127.0.0.1 --format=2025   # F1 25 layout
python3 Tools/f1_sim.py 192.168.1.42              # a real iPhone
```

Tests cover the binary parsing for both formats, byte by byte:

```bash
xcodebuild test -scheme ApexDash -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Requires iOS 17.

## How this was built

This app was written with an AI coding assistant, which is why the commit log
carries `Co-Authored-By` lines. The design was drawn by hand against reference
frames, the packet offsets were verified against EA's published specifications
and confirmed against real sessions, and the parsing is covered by tests. Judge
it on those, not on who typed it.

## Licence and trademarks

MIT. See [LICENSE](LICENSE).

Not affiliated with, endorsed by, or connected to Formula One, EA, or
Codemasters. F1 and Formula 1 are trademarks of Formula One Licensing BV, used
here only to say which games this reads telemetry from.
