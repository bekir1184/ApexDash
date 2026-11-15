import Foundation

// Assetto Corsa Competizione broadcasting protocol, version 4.
//
// Source: the broadcasting SDK Kunos ships with the game, in
// "Assetto Corsa Competizione/sdk/broadcasting" (BroadcastingNetworkProtocol.cs).
// All values are little-endian. Strings are a UInt16 byte count followed by
// UTF-8 bytes. Unlike F1, the game only sends after a client registers.

enum ACCProtocol {
    static let version: UInt8 = 4
    /// Int32.max stands for "no time" in lap times and splits.
    static let noTime = Int(Int32.max)
}

/// Messages the app sends to the game.
enum ACCOutbound: UInt8 {
    case registerCommandApplication = 1
    case unregisterCommandApplication = 9
    case requestEntryList = 10
    case requestTrackData = 11
}

/// Messages the game sends.
enum ACCInbound: UInt8 {
    case registrationResult = 1
    case realtimeUpdate = 2
    case realtimeCarUpdate = 3
    case entryList = 4
    case trackData = 5
    case entryListCar = 6
    case broadcastingEvent = 7
}

// MARK: - Requests

enum ACCRequest {
    /// Registers the app. The game then sends realtime updates every `intervalMS`.
    static func register(displayName: String, password: String, intervalMS: Int32,
                         commandPassword: String = "") -> Data {
        var w = ByteWriter()
        w.uint8(ACCOutbound.registerCommandApplication.rawValue)
        w.uint8(ACCProtocol.version)
        w.accString(displayName)
        w.accString(password)
        w.int32(intervalMS)
        w.accString(commandPassword)
        return w.data
    }

    static func unregister(connectionID: Int32) -> Data {
        message(.unregisterCommandApplication, connectionID: connectionID)
    }

    static func trackData(connectionID: Int32) -> Data {
        message(.requestTrackData, connectionID: connectionID)
    }

    static func entryList(connectionID: Int32) -> Data {
        message(.requestEntryList, connectionID: connectionID)
    }

    private static func message(_ type: ACCOutbound, connectionID: Int32) -> Data {
        var w = ByteWriter()
        w.uint8(type.rawValue)
        w.int32(connectionID)
        return w.data
    }
}

// MARK: - Replies

struct ACCRegistrationResult: Equatable {
    let connectionID: Int32
    let success: Bool
    let isReadOnly: Bool
    let error: String

    init?(data: Data) {
        var r = ByteReader(data, offset: 1)
        guard data.first == ACCInbound.registrationResult.rawValue,
              let id = r.int32(), let success = r.uint8(), let writable = r.uint8(),
              let error = r.accString()
        else { return nil }
        connectionID = id
        self.success = success > 0
        isReadOnly = writable == 0
        self.error = error
    }
}

/// A lap as the game reports it: running, last or best.
struct ACCLap: Equatable {
    /// Lap time in milliseconds; nil when the game has no time yet.
    let timeMS: Int?
    let carIndex: Int
    let driverIndex: Int
    /// Sector times in milliseconds; nil for sectors not driven yet.
    let splits: [Int?]
    let isInvalid: Bool
    let isValidForBest: Bool
    let isOutLap: Bool
    let isInLap: Bool

    init?(reader r: inout ByteReader) {
        guard let time = r.int32(), let car = r.uint16(), let driver = r.uint16(),
              let splitCount = r.uint8()
        else { return nil }
        var splits: [Int?] = []
        for _ in 0..<splitCount {
            guard let split = r.int32() else { return nil }
            splits.append(ACCLap.time(split))
        }
        guard let invalid = r.uint8(), let validForBest = r.uint8(),
              let outLap = r.uint8(), let inLap = r.uint8()
        else { return nil }
        timeMS = ACCLap.time(time)
        carIndex = Int(car)
        driverIndex = Int(driver)
        self.splits = splits
        isInvalid = invalid > 0
        isValidForBest = validForBest > 0
        isOutLap = outLap > 0
        isInLap = inLap > 0
    }

    private static func time(_ raw: Int32) -> Int? {
        Int(raw) == ACCProtocol.noTime ? nil : Int(raw)
    }

    /// Sector time, or 0 when the sector has not been driven.
    func split(_ index: Int) -> Int {
        splits.indices.contains(index) ? splits[index] ?? 0 : 0
    }

    /// Number of sectors already driven in this lap.
    var completedSectors: Int { splits.prefix { $0 != nil }.count }
}

/// Session-wide state, sent once per update interval.
struct ACCRealtimeUpdate: Equatable {
    let eventIndex: Int
    let sessionIndex: Int
    let sessionType: Int
    let phase: Int
    let sessionTimeMS: Float
    let sessionEndTimeMS: Float
    /// The car the camera follows: the player's car when driving.
    let focusedCarIndex: Int
    let timeOfDayMS: Float
    let ambientTemp: Int
    let trackTemp: Int
    /// 0...1
    let clouds: Float
    let rainLevel: Float
    let wetness: Float
    let bestSessionLap: ACCLap

    init?(data: Data) {
        var r = ByteReader(data, offset: 1)
        guard data.first == ACCInbound.realtimeUpdate.rawValue,
              let event = r.uint16(), let session = r.uint16(),
              let type = r.uint8(), let phase = r.uint8(),
              let time = r.float(), let end = r.float(),
              let focused = r.int32(),
              r.accString() != nil, r.accString() != nil, r.accString() != nil,   // camera set, camera, HUD page
              let replay = r.uint8()
        else { return nil }
        if replay > 0 { r.skip(8) }           // replay session time and remaining time
        guard let timeOfDay = r.float(), let ambient = r.uint8(), let track = r.uint8(),
              let clouds = r.uint8(), let rain = r.uint8(), let wetness = r.uint8(),
              let best = ACCLap(reader: &r)
        else { return nil }
        eventIndex = Int(event)
        sessionIndex = Int(session)
        sessionType = Int(type)
        self.phase = Int(phase)
        sessionTimeMS = time
        sessionEndTimeMS = end
        focusedCarIndex = Int(focused)
        timeOfDayMS = timeOfDay
        ambientTemp = Int(ambient)
        trackTemp = Int(track)
        self.clouds = Float(clouds) / 10
        rainLevel = Float(rain) / 10
        self.wetness = Float(wetness) / 10
        bestSessionLap = best
    }
}

/// Where a car is: on track, in the pit lane or between them.
enum ACCCarLocation: Int {
    case none = 0, track, pitlane, pitEntry, pitExit
}

/// One car's state, sent for every car once per update interval.
struct ACCCarUpdate: Equatable {
    let carIndex: Int
    let driverIndex: Int
    let driverCount: Int
    /// -1 reverse, 0 neutral, 1... forward gears.
    let gear: Int
    /// Map position in metres.
    let worldX: Float
    let worldY: Float
    let yaw: Float
    let location: ACCCarLocation
    let speedKPH: Int
    let position: Int
    let cupPosition: Int
    let trackPosition: Int
    /// Progress along the lap, 0...1.
    let splinePosition: Float
    /// Laps completed.
    let laps: Int
    /// Gap to the session best lap at this point, in milliseconds.
    let deltaMS: Int
    let bestSessionLap: ACCLap
    let lastLap: ACCLap
    let currentLap: ACCLap

    init?(data: Data) {
        var r = ByteReader(data, offset: 1)
        guard data.first == ACCInbound.realtimeCarUpdate.rawValue,
              let car = r.uint16(), let driver = r.uint16(), let drivers = r.uint8(),
              let gear = r.uint8(), let x = r.float(), let y = r.float(), let yaw = r.float(),
              let location = r.uint8(), let kmh = r.uint16(),
              let position = r.uint16(), let cup = r.uint16(), let trackPosition = r.uint16(),
              let spline = r.float(), let laps = r.uint16(), let delta = r.int32(),
              let best = ACCLap(reader: &r), let last = ACCLap(reader: &r), let current = ACCLap(reader: &r)
        else { return nil }
        carIndex = Int(car)
        driverIndex = Int(driver)
        driverCount = Int(drivers)
        self.gear = Int(gear) - 2
        worldX = x
        worldY = y
        self.yaw = yaw
        self.location = ACCCarLocation(rawValue: Int(location)) ?? .none
        speedKPH = Int(kmh)
        self.position = Int(position)
        cupPosition = Int(cup)
        self.trackPosition = Int(trackPosition)
        splinePosition = spline
        self.laps = Int(laps)
        deltaMS = Int(delta)
        bestSessionLap = best
        lastLap = last
        currentLap = current
    }
}

/// Track name and length, sent in reply to a track data request.
struct ACCTrackData: Equatable {
    let connectionID: Int32
    let name: String
    let id: Int
    let lengthMetres: Int

    init?(data: Data) {
        var r = ByteReader(data, offset: 1)
        guard data.first == ACCInbound.trackData.rawValue,
              let connection = r.int32(), let name = r.accString(),
              let id = r.int32(), let length = r.int32()
        else { return nil }
        // Camera sets and HUD pages follow; the app does not use them.
        connectionID = connection
        self.name = name
        self.id = Int(id)
        lengthMetres = Int(length)
    }
}

// MARK: - Strings

extension ByteReader {
    /// A UInt16 byte count followed by UTF-8 bytes.
    mutating func accString() -> String? {
        guard let count = uint16(), let bytes = bytes(Int(count)) else { return nil }
        return String(decoding: bytes, as: UTF8.self)
    }
}

extension ByteWriter {
    mutating func accString(_ value: String) {
        let bytes = Data(value.utf8.prefix(Int(UInt16.max)))
        uint16(UInt16(bytes.count))
        self.bytes(bytes)
    }
}
