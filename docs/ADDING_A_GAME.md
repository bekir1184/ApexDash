# Adding a game

Apex Dash reads telemetry that racing games send over UDP. Supporting a new game
means teaching the app to decode that game's datagrams. Everything else,
dashboards, lap timing, traces and the analysis page, already works.

Good candidates publish a documented UDP output:

| Game | Output | Notes |
| --- | --- | --- |
| Forza Motorsport, Forza Horizon | "Data Out", fixed-size UDP packets | Simple, one packet type |
| EA SPORTS WRC, DiRT Rally 2.0 | Codemasters UDP | Similar to older F1 games |
| Assetto Corsa Competizione | Broadcasting UDP API | Needs a registration handshake |
| Gran Turismo 7 | Encrypted UDP | Needs a heartbeat and decryption |

Pick one, open an issue saying you are working on it, and follow the steps below.

## 1. Read the specification

Find the game's official telemetry documentation, or a well-known community
reference. Note the byte order, packet sizes and field offsets. Link the source
in your pull request.

## 2. Create the game folder

```
Sources/Games/Forza/
  ForzaGame.swift        TelemetryGame implementation
  ForzaPackets.swift     Packet structs parsed with ByteReader
  ForzaDemoDrive.swift   Optional: a simulated session
Tests/ForzaPacketTests.swift
```

Run `xcodegen generate` after adding files.

## 3. Parse packets

Use `ByteReader`, which reads little-endian fields without relying on memory
layout. Return `nil` when a packet is too short.

```swift
struct ForzaSled {
    let isRaceOn: Bool
    let engineMaxRPM: Float
    let currentRPM: Float
    // ...

    init?(data: Data) {
        var r = ByteReader(data)
        guard let raceOn = r.int32(), let maxRPM = r.float(),
              let idle = r.float(), let rpm = r.float() else { return nil }
        isRaceOn = raceOn != 0
        engineMaxRPM = maxRPM
        currentRPM = rpm
        _ = idle
    }
}
```

## 4. Implement `TelemetryGame`

```swift
@MainActor
final class ForzaGame: TelemetryGame {
    static let id = "forza"                    // stored in settings; never change it
    static let displayName = "Forza Motorsport"
    static let defaultPort: UInt16 = 5300

    private var timing = LapTiming()

    func consume(_ data: Data, sink: TelemetrySink) -> Bool {
        guard let packet = ForzaDash(data: data) else { return false }
        sink.dash.speedKPH = Int(packet.speed * 3.6)
        sink.dash.gear = packet.gear
        sink.dash.rpm = Int(packet.currentRPM)
        sink.dash.maxRPM = Int(packet.engineMaxRPM)
        sink.dash.throttle = packet.throttle
        sink.dash.brake = packet.brake
        // ...
        timing.ingest(lapNumber: packet.lapNumber, lastLapTimeMS: packet.lastLapMS, sector: 0,
                      sector1MS: 0, sector2MS: 0, distance: packet.distance,
                      currentLapTimeMS: packet.currentLapMS)
        sink.dash.applyTiming(timing)
        return true
    }

    func reset() {
        timing = LapTiming()
    }
}
```

Rules of thumb:

- **Return `false`** for datagrams that are not this game's. Only recognised
  datagrams count as a live connection.
- **Fill what the game provides.** Fields you cannot fill keep their defaults,
  and dashboards hide or zero them.
- **Rev lights:** if the game has no shift light data, compute
  `revLightsPercent` and `revLightsBits` from RPM.
- **Lap traces:** to feed the analysis page, record `TraceSample`s during the
  lap and call `sink.publish(lapTraces:)` when a lap ends. See
  `F1TraceRecorder`.
- **Track name:** set `SessionInfo.trackName` and call `sink.publish(session:)`.
- **Wrong format:** if the game can send several layouts, call
  `sink.reportUnexpectedFormat(_:)` so the player sees what to change.

## 5. Test with real bytes

Build packets byte by byte in tests, the way `PacketParsingTests` does for F1,
and assert every field you read. If you can, also record a few real datagrams
from the game and add them as test fixtures.

A demo drive (`makeDemo()`) is optional but makes review much easier: it lets
anyone see your game working without owning it.

## 6. Let players choose the game

Game selection lives in the connection screen. Until more than one game exists,
`RootDashboardView` creates `F1Game` directly; the first new game should add a
picker there, storing `TelemetryGame.id` in settings. Mention it in your pull
request and we will shape it together.

## 7. Document the setup

Add the in-game telemetry settings to the README's supported games table.
