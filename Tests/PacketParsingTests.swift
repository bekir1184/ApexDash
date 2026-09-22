import XCTest
@testable import ApexDash

/// Builds packets byte by byte and feeds them to the parsers. The two games' layouts
/// differ, so everything is checked in both formats.
final class PacketParsingTests: XCTestCase {

    // MARK: - Byte builder

    /// Builds packed little-endian packets, exactly as laid out in the specification.
    struct PacketBuilder {
        var bytes: [UInt8] = []

        mutating func u8(_ v: UInt8) { bytes.append(v) }
        mutating func i8(_ v: Int8) { bytes.append(UInt8(bitPattern: v)) }
        mutating func u16(_ v: UInt16) { bytes.append(contentsOf: [UInt8(v & 0xff), UInt8(v >> 8)]) }
        mutating func i16(_ v: Int16) { u16(UInt16(bitPattern: v)) }
        mutating func u32(_ v: UInt32) {
            for i in 0..<4 { bytes.append(UInt8((v >> (8 * UInt32(i))) & 0xff)) }
        }
        mutating func u64(_ v: UInt64) {
            for i in 0..<8 { bytes.append(UInt8((v >> (8 * UInt64(i))) & 0xff)) }
        }
        mutating func f32(_ v: Float) { u32(v.bitPattern) }
        mutating func pad(_ count: Int) { bytes.append(contentsOf: [UInt8](repeating: 0, count: count)) }
        mutating func text(_ s: String, length: Int) {
            var raw = Array(s.utf8.prefix(length))
            raw.append(contentsOf: [UInt8](repeating: 0, count: length - raw.count))
            bytes.append(contentsOf: raw)
        }

        var data: Data { Data(bytes) }
    }

    private func header(format: UInt16, packetID: UInt8, playerIndex: UInt8 = 0) -> PacketBuilder {
        var b = PacketBuilder()
        b.u16(format)                 // m_packetFormat
        b.u8(UInt8(format % 100))     // m_gameYear
        b.u8(1); b.u8(0)              // major, minor
        b.u8(1)                       // m_packetVersion
        b.u8(packetID)
        b.u64(0xDEAD_BEEF)            // m_sessionUID
        b.f32(12.5)                   // m_sessionTime
        b.u32(900)                    // m_frameIdentifier
        b.u32(900)                    // m_overallFrameIdentifier
        b.u8(playerIndex)
        b.u8(255)                     // m_secondaryPlayerCarIndex
        return b
    }

    // MARK: - Header

    func testHeaderReadsBothSupportedFormats() throws {
        let f125 = try XCTUnwrap(PacketHeader(header(format: 2025, packetID: 6, playerIndex: 3).data))
        XCTAssertEqual(f125.format, .f125)
        XCTAssertEqual(f125.packetID, .carTelemetry)
        XCTAssertEqual(f125.playerCarIndex, 3)

        let f126 = try XCTUnwrap(PacketHeader(header(format: 2026, packetID: 2).data))
        XCTAssertEqual(f126.format, .f126)
        XCTAssertEqual(f126.packetID, .lapData)
    }

    func testHeaderIsExactlyTwentyNineBytes() {
        XCTAssertEqual(header(format: 2026, packetID: 0).bytes.count, PacketHeader.size)
    }

    func testHeaderRejectsUnsupportedFormat() {
        XCTAssertNil(PacketHeader(header(format: 2024, packetID: 6).data))
        XCTAssertNil(PacketHeader(header(format: 2026, packetID: 99).data))
    }

    func testHeaderRejectsShortPacket() {
        let short = header(format: 2026, packetID: 6).data.prefix(20)
        XCTAssertNil(PacketHeader(Data(short)))
    }

    // MARK: - Telemetry

    /// Builds one car's telemetry record. Engine temperature is two bytes in F1 25 and one
    /// in F1 26; the other fields are the same.
    private func telemetryCar(format: PacketFormat, speed: UInt16, gear: Int8, rpm: UInt16,
                              drs: Bool, engineTemp: Int, brake: Float) -> PacketBuilder {
        var b = PacketBuilder()
        b.u16(speed)
        b.f32(1.0)                    // throttle
        b.f32(-0.25)                  // steer
        b.f32(brake)
        b.u8(0)                       // clutch
        b.i8(gear)
        b.u16(rpm)
        b.u8(drs ? 1 : 0)
        b.u8(72)                      // revLightsPercent
        b.u16(0b0000_0000_0111_1111)  // revLightsBitValue
        for t in [420, 415, 480, 470] { b.u16(UInt16(t)) }   // brakesTemperature
        for t in [96, 98, 92, 94] { b.u8(UInt8(t)) }         // tyresSurfaceTemperature
        for t in [101, 103, 97, 99] { b.u8(UInt8(t)) }       // tyresInnerTemperature
        if format == .f126 { b.u8(UInt8(engineTemp)) } else { b.u16(UInt16(engineTemp)) }
        for p in [23.5, 23.4, 21.9, 22.0] { b.f32(Float(p)) } // tyresPressure
        b.pad(4)                                             // surfaceType
        return b
    }

    func testCarTelemetryStrideMatchesSpecForBothFormats() {
        XCTAssertEqual(telemetryCar(format: .f126, speed: 0, gear: 0, rpm: 0,
                                    drs: false, engineTemp: 100, brake: 0).bytes.count,
                       PacketFormat.f126.telemetryStride)
        XCTAssertEqual(telemetryCar(format: .f125, speed: 0, gear: 0, rpm: 0,
                                    drs: false, engineTemp: 100, brake: 0).bytes.count,
                       PacketFormat.f125.telemetryStride)
    }

    func testCarTelemetryParsesF126() throws {
        var b = header(format: 2026, packetID: 6)
        b.bytes += telemetryCar(format: .f126, speed: 274, gear: 7, rpm: 11_650,
                                drs: true, engineTemp: 108, brake: 0).bytes
        let t = try XCTUnwrap(CarTelemetry(data: b.data, carIndex: 0, format: .f126))
        XCTAssertEqual(t.speedKPH, 274)
        XCTAssertEqual(t.gear, 7)
        XCTAssertEqual(t.engineRPM, 11_650)
        XCTAssertEqual(t.engineTemp, 108)
        XCTAssertEqual(t.throttle, 1.0)
        XCTAssertEqual(t.brakeTemps, [420, 415, 480, 470])
        XCTAssertEqual(t.tyreSurfaceTemps, [96, 98, 92, 94])
        // No DRS under the 2026 regulations: the byte is read but never reaches the model.
        XCTAssertFalse(t.drsActive)
    }

    func testCarTelemetryParsesF125WithWideEngineTempAndDRS() throws {
        var b = header(format: 2025, packetID: 6)
        b.bytes += telemetryCar(format: .f125, speed: 312, gear: 8, rpm: 12_900,
                                drs: true, engineTemp: 300, brake: 0).bytes
        let t = try XCTUnwrap(CarTelemetry(data: b.data, carIndex: 0, format: .f125))
        XCTAssertEqual(t.speedKPH, 312)
        XCTAssertEqual(t.gear, 8)
        // Read as a single byte, 300 would not fit and would come out as 44.
        XCTAssertEqual(t.engineTemp, 300)
        XCTAssertTrue(t.drsActive)
    }

    /// Reading the second car correctly proves the stride length is right.
    func testCarTelemetryUsesFormatStrideForSecondCar() throws {
        for format in [PacketFormat.f125, .f126] {
            var b = header(format: format.rawValue, packetID: 6)
            b.bytes += telemetryCar(format: format, speed: 100, gear: 3, rpm: 9_000,
                                    drs: false, engineTemp: 90, brake: 0).bytes
            b.bytes += telemetryCar(format: format, speed: 205, gear: 6, rpm: 11_000,
                                    drs: true, engineTemp: 95, brake: 1).bytes
            let second = try XCTUnwrap(CarTelemetry(data: b.data, carIndex: 1, format: format))
            XCTAssertEqual(second.speedKPH, 205, "\(format.label) ikinci arac")
            XCTAssertEqual(second.gear, 6)
            XCTAssertEqual(second.brake, 1)
        }
    }

    func testCarTelemetryRejectsTruncatedCar() {
        var b = header(format: 2026, packetID: 6)
        b.bytes += telemetryCar(format: .f126, speed: 100, gear: 1, rpm: 5_000,
                                drs: false, engineTemp: 90, brake: 0).bytes.dropLast(10)
        XCTAssertNil(CarTelemetry(data: b.data, carIndex: 0, format: .f126))
    }

    // MARK: - Car status

    private func statusCar(format: PacketFormat, limiter: Bool, drsAllowed: Bool,
                           maxRPM: UInt16, flag: Int8, store: Float,
                           harvestMGUK: Float, harvestLimit: Float, deployed: Float) -> PacketBuilder {
        var b = PacketBuilder()
        b.u8(1); b.u8(0); b.u8(1); b.u8(55)   // tc, abs, fuelMix, frontBrakeBias
        b.u8(limiter ? 1 : 0)
        b.f32(90); b.f32(110)                 // fuelInTank, fuelCapacity
        b.f32(3.2)                            // fuelRemainingLaps
        b.u16(maxRPM); b.u16(4_000); b.u8(8)  // maxRPM, idleRPM, maxGears
        b.u8(drsAllowed ? 1 : 0)
        b.u16(0)                              // drsActivationDistance
        b.u8(18); b.u8(18); b.u8(4)           // actual, visual, tyre age
        b.i8(flag)
        b.f32(0); b.f32(0)                    // enginePowerICE, MGUK
        b.f32(store)
        b.u8(2)                               // ersDeployMode
        b.f32(harvestMGUK); b.f32(200_000)    // harvested MGUK, MGUH
        if format == .f126 { b.f32(harvestLimit) }
        b.f32(deployed)
        b.u8(0)                               // networkPaused
        return b
    }

    func testCarStatusStrideMatchesSpecForBothFormats() {
        for format in [PacketFormat.f125, .f126] {
            let car = statusCar(format: format, limiter: false, drsAllowed: false, maxRPM: 15_000,
                                flag: 0, store: 0, harvestMGUK: 0, harvestLimit: 0, deployed: 0)
            XCTAssertEqual(car.bytes.count, format.statusStride, "\(format.label)")
        }
    }

    func testCarStatusParsesF126HarvestLimit() throws {
        var b = header(format: 2026, packetID: 7)
        b.bytes += statusCar(format: .f126, limiter: true, drsAllowed: true, maxRPM: 15_000,
                             flag: 3, store: 2_800_000, harvestMGUK: 1_400_000,
                             harvestLimit: 8_000_000, deployed: 900_000).bytes
        let s = try XCTUnwrap(CarStatus(data: b.data, carIndex: 0, format: .f126))
        XCTAssertTrue(s.pitLimiterOn)
        XCTAssertEqual(s.maxRPM, 15_000)
        XCTAssertEqual(s.fiaFlag, 3)
        XCTAssertEqual(s.ersStoreEnergy, 2_800_000)
        XCTAssertEqual(s.ersHarvestedThisLap, 1_600_000)   // MGU-K + MGU-H
        XCTAssertEqual(s.ersHarvestLimitPerLap, 8_000_000)
        XCTAssertEqual(s.ersDeployedThisLap, 900_000)
        // No DRS in 2026.
        XCTAssertFalse(s.drsAllowed)
    }

    func testCarStatusParsesF125WithoutHarvestLimit() throws {
        var b = header(format: 2025, packetID: 7)
        b.bytes += statusCar(format: .f125, limiter: false, drsAllowed: true, maxRPM: 13_000,
                             flag: 1, store: 4_000_000, harvestMGUK: 1_000_000,
                             harvestLimit: 0, deployed: 750_000).bytes
        let s = try XCTUnwrap(CarStatus(data: b.data, carIndex: 0, format: .f125))
        XCTAssertEqual(s.maxRPM, 13_000)
        XCTAssertEqual(s.ersStoreEnergy, 4_000_000)
        XCTAssertEqual(s.ersDeployedThisLap, 750_000)
        // No such field: it stays zero, so dashboards scale against the store.
        XCTAssertEqual(s.ersHarvestLimitPerLap, 0)
        XCTAssertTrue(s.drsAllowed)
    }

    // MARK: - Lap data

    private func lapCar(lastLap: UInt32, currentLap: UInt32, s1: UInt16, s2: UInt16,
                        distance: Float, position: UInt8, lapNumber: UInt8,
                        sector: UInt8, invalid: Bool) -> PacketBuilder {
        var b = PacketBuilder()
        b.u32(lastLap); b.u32(currentLap)
        b.u16(s1); b.u8(0)
        b.u16(s2); b.u8(0)
        b.u16(1_240); b.u8(0)                 // deltaToCarInFront
        b.u16(5_000); b.u8(0)                 // deltaToRaceLeader
        b.f32(distance); b.f32(12_000); b.f32(0)
        b.u8(position); b.u8(lapNumber)
        b.u8(0); b.u8(0)                      // pitStatus, numPitStops
        b.u8(sector); b.u8(invalid ? 1 : 0)
        b.pad(9)                              // penalties ... pitLaneTimerActive
        b.u16(0); b.u16(0); b.u8(0)           // pit lane timers
        b.f32(312.5); b.u8(12)                // speed trap
        return b
    }

    func testLapDataStrideIsFiftySevenInBothFormats() {
        let car = lapCar(lastLap: 0, currentLap: 0, s1: 0, s2: 0, distance: 0,
                         position: 1, lapNumber: 1, sector: 0, invalid: false)
        XCTAssertEqual(car.bytes.count, LapData.stride)
        XCTAssertEqual(PacketFormat.f125.lapStride, PacketFormat.f126.lapStride)
    }

    func testLapDataParsesPlayerCar() throws {
        var b = header(format: 2026, packetID: 2, playerIndex: 1)
        b.bytes += lapCar(lastLap: 0, currentLap: 0, s1: 0, s2: 0, distance: 0,
                          position: 9, lapNumber: 1, sector: 0, invalid: false).bytes
        b.bytes += lapCar(lastLap: 88_412, currentLap: 41_236, s1: 28_186, s2: 30_004,
                          distance: 2_450.5, position: 4, lapNumber: 12,
                          sector: 1, invalid: true).bytes
        let l = try XCTUnwrap(LapData(data: b.data, carIndex: 1, format: .f126))
        XCTAssertEqual(l.lastLapTimeMS, 88_412)
        XCTAssertEqual(l.currentLapTimeMS, 41_236)
        XCTAssertEqual(l.sector1MS, 28_186)
        XCTAssertEqual(l.sector2MS, 30_004)
        XCTAssertEqual(l.carPosition, 4)
        XCTAssertEqual(l.currentLapNum, 12)
        XCTAssertEqual(l.sector, 1)
        XCTAssertTrue(l.currentLapInvalid)
        XCTAssertEqual(l.lapDistance, 2_450.5)
    }

    /// Sector times over a minute combine with their minutes part.
    func testLapDataCombinesSectorMinutes() throws {
        var b = header(format: 2026, packetID: 2)
        var car = PacketBuilder()
        car.u32(0); car.u32(0)
        car.u16(5_000); car.u8(1)             // 1 minute 5 seconds
        car.u16(0); car.u8(0)
        car.pad(6)
        car.f32(0); car.f32(0); car.f32(0)
        car.pad(6)
        car.pad(9)
        car.u16(0); car.u16(0); car.u8(0)
        car.f32(0); car.u8(0)
        b.bytes += car.bytes
        let l = try XCTUnwrap(LapData(data: b.data, carIndex: 0, format: .f126))
        XCTAssertEqual(l.sector1MS, 65_000)
    }

    func testPositionsReadEveryCarInFormat() throws {
        for format in [PacketFormat.f125, .f126] {
            var b = header(format: format.rawValue, packetID: 2)
            for index in 0..<format.cars {
                b.bytes += lapCar(lastLap: 0, currentLap: 0, s1: 0, s2: 0, distance: 0,
                                  position: UInt8(index + 1), lapNumber: 1,
                                  sector: 0, invalid: false).bytes
            }
            let positions = LapData.positions(in: b.data, format: format)
            XCTAssertEqual(positions.count, format.cars, "\(format.label)")
            XCTAssertEqual(positions.first, 1)
            XCTAssertEqual(positions.last, format.cars)
        }
    }

    // MARK: - Participants

    private func participant(format: PacketFormat, raceNumber: UInt8, name: String,
                             colour: (UInt8, UInt8, UInt8)) -> PacketBuilder {
        var b = PacketBuilder()
        b.u8(1)                               // aiControlled
        if format == .f126 {
            b.u16(11); b.u16(0); b.u16(2)     // driverId, networkId, teamId (uint16)
        } else {
            b.u8(11); b.u8(0); b.u8(2)        // the same fields as uint8
        }
        b.u8(0)                               // myTeam
        b.u8(raceNumber)
        b.u8(1)                               // nationality
        b.text(name, length: 32)
        b.u8(1); b.u8(1)                      // yourTelemetry, showOnlineNames
        b.u16(0)                              // techLevel
        b.u8(1)                               // platform
        b.u8(1)                               // numColours
        b.u8(colour.0); b.u8(colour.1); b.u8(colour.2)
        b.pad(9)                              // remaining three colours
        return b
    }

    func testParticipantStrideMatchesSpecForBothFormats() {
        for format in [PacketFormat.f125, .f126] {
            let p = participant(format: format, raceNumber: 44, name: "X", colour: (0, 0, 0))
            XCTAssertEqual(p.bytes.count, format.participantStride, "\(format.label)")
        }
    }

    func testParticipantsParseNamesAndNumbersInBothFormats() throws {
        for format in [PacketFormat.f125, .f126] {
            var b = header(format: format.rawValue, packetID: 4)
            b.u8(2)                                             // numActiveCars
            b.bytes += participant(format: format, raceNumber: 44,
                                   name: "Lewis Hamilton", colour: (0, 210, 190)).bytes
            b.bytes += participant(format: format, raceNumber: 63,
                                   name: "George Russell", colour: (0, 210, 190)).bytes
            let list = ParticipantsPacket.parse(b.data, format: format)
            // The packet ends after two records: the parser stops when the data runs out.
            XCTAssertEqual(list.count, 2, "\(format.label)")
            XCTAssertEqual(list[0].name, "Lewis Hamilton")
            XCTAssertEqual(list[0].raceNumber, 44)
            XCTAssertEqual(list[0].surname, "HAMILTON")
            XCTAssertEqual(list[1].name, "George Russell")
            XCTAssertEqual(list[1].raceNumber, 63)
            let colour = try XCTUnwrap(list[0].teamColour)
            XCTAssertEqual(colour.green, 210.0 / 255, accuracy: 0.001)
        }
    }

    // MARK: - Motion

    private func motionCar(format: PacketFormat, x: Float, z: Float,
                           gLat: Float, gLong: Float, yaw: Float) -> PacketBuilder {
        var b = PacketBuilder()
        b.f32(x); b.f32(0); b.f32(z)          // dunya konumu
        b.f32(30); b.f32(0); b.f32(40)        // velocity vector
        for _ in 0..<6 { b.i16(0) }           // direction vectors
        if format == .f126 {
            b.i16(Int16(gLat * 1000)); b.i16(Int16(gLong * 1000)); b.i16(1000)
        } else {
            b.f32(gLat); b.f32(gLong); b.f32(1)
        }
        b.f32(yaw); b.f32(0); b.f32(0)        // yaw, pitch, roll
        return b
    }

    func testMotionStrideMatchesSpecForBothFormats() {
        for format in [PacketFormat.f125, .f126] {
            let car = motionCar(format: format, x: 0, z: 0, gLat: 0, gLong: 0, yaw: 0)
            XCTAssertEqual(car.bytes.count, format.motionStride, "\(format.label)")
        }
    }

    func testMotionParsesPositionAndGForcesInBothFormats() throws {
        for format in [PacketFormat.f125, .f126] {
            var b = header(format: format.rawValue, packetID: 0)
            b.bytes += motionCar(format: format, x: 624.25, z: -986.5,
                                 gLat: 3.25, gLong: -1.5, yaw: 1.25).bytes
            let m = try XCTUnwrap(CarMotion(data: b.data, carIndex: 0, format: format))
            XCTAssertEqual(m.worldX, 624.25)
            XCTAssertEqual(m.worldZ, -986.5)
            XCTAssertEqual(m.yaw, 1.25)
            XCTAssertEqual(m.gLateral, 3.25, accuracy: 0.001, "\(format.label) yanal G")
            XCTAssertEqual(m.gLongitudinal, -1.5, accuracy: 0.001)
            XCTAssertEqual(m.speedMS, 50, accuracy: 0.001)   // 30-40-50 triangle
        }
    }

    // MARK: - Session and events

    func testSessionInfoReadsTrackAndWeather() throws {
        var b = header(format: 2026, packetID: 1)
        b.u8(1)                               // weather: light cloud
        b.i8(41); b.i8(27)                    // track, air temperature
        b.u8(20)                              // totalLaps
        b.u16(5_793)                          // trackLength
        b.u8(10)                              // sessionType
        b.i8(11)                              // trackId: Monza
        b.pad(200)
        let info = try XCTUnwrap(SessionInfo(data: b.data))
        XCTAssertEqual(info.weather, 1)
        XCTAssertEqual(info.trackTemperature, 41)
        XCTAssertEqual(info.airTemperature, 27)
        XCTAssertEqual(info.trackLength, 5_793)
        XCTAssertEqual(info.trackID, 11)
    }

    func testStartLightsAndLightsOutEvents() throws {
        var lights = header(format: 2026, packetID: 3)
        lights.text("STLG", length: 4)
        lights.u8(3)
        lights.pad(45 - 29 - 5)
        guard case .startLights(let count) = GameEvent(data: lights.data) else {
            return XCTFail("STLG okunamadi")
        }
        XCTAssertEqual(count, 3)

        var out = header(format: 2026, packetID: 3)
        out.text("LGOT", length: 4)
        out.pad(45 - 29 - 4)
        guard case .lightsOut = GameEvent(data: out.data) else {
            return XCTFail("LGOT okunamadi")
        }
    }

    // MARK: - Format table

    /// Packet sizes from the official specification: header + cars * stride.
    func testPacketSizesMatchPublishedSpec() {
        // F1 25: motion 1349, lap 1285, telemetry 1352, status 1239, participants 1284
        XCTAssertEqual(29 + 22 * PacketFormat.f125.motionStride, 1349)
        XCTAssertEqual(29 + 22 * PacketFormat.f125.lapStride + 2, 1285)
        XCTAssertEqual(29 + 22 * PacketFormat.f125.telemetryStride + 3, 1352)
        XCTAssertEqual(29 + 22 * PacketFormat.f125.statusStride, 1239)
        XCTAssertEqual(29 + 1 + 22 * PacketFormat.f125.participantStride, 1284)
        XCTAssertEqual(PacketFormat.f125.cars, 22)
        XCTAssertEqual(PacketFormat.f126.cars, 24)
        XCTAssertFalse(PacketFormat.f125.hasActiveAero)
        XCTAssertTrue(PacketFormat.f126.hasActiveAero)
    }
}
