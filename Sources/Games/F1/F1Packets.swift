import Foundation

/// Desteklenen UDP bicimleri. Iki oyunun paket duzeni bir kismi disinda
/// aynidir; farklar burada toplanir, ayristiricilar buradan okur.
///
/// F1 25 (2025): 22 arac, telemetride DRS baytı ve uint16 motor sicakligi,
/// durum paketinde tur basina toplama limiti yok, hareket paketinde G
/// kuvvetleri float, aktif aero / overtake paketi (16) hic gonderilmez.
/// F1 26 (2026): 24 arac, DRS kaldirildi, yerine aktif aero ve overtake.
enum PacketFormat: UInt16 {
    case f125 = 2025
    case f126 = 2026

    /// Paketlerdeki arac dizisi uzunlugu.
    var cars: Int { self == .f126 ? 24 : 22 }
    var telemetryStride: Int { self == .f126 ? 59 : 60 }
    var statusStride: Int { self == .f126 ? 59 : 55 }
    var participantStride: Int { self == .f126 ? 60 : 57 }
    var motionStride: Int { self == .f126 ? 54 : 60 }
    /// Iki bicimde de ayni.
    var lapStride: Int { 57 }
    /// 2026 kurallari: DRS yok, aktif aero ve overtake var.
    var hasActiveAero: Bool { self == .f126 }
    var label: String { self == .f126 ? "F1 26" : "F1 25" }
}

enum PacketID: UInt8 {
    case motion = 0
    case session = 1
    case lapData = 2
    case event = 3
    case participants = 4
    case carSetups = 5
    case carTelemetry = 6
    case carStatus = 7
    case finalClassification = 8
    case lobbyInfo = 9
    case carDamage = 10
    case sessionHistory = 11
    case tyreSets = 12
    case motionEx = 13
    case timeTrial = 14
    case lapPositions = 15
    case carTelemetry2 = 16
}

struct PacketHeader {
    static let size = 29

    let format: PacketFormat
    let gameYear: UInt8
    let packetVersion: UInt8
    let packetID: PacketID
    let sessionUID: UInt64
    let sessionTime: Float
    let frameIdentifier: UInt32
    let playerCarIndex: Int

    init?(_ data: Data) {
        var r = ByteReader(data)
        guard let format = r.uint16(),
              let year = r.uint8(),
              r.uint8() != nil,            // gameMajorVersion
              r.uint8() != nil,            // gameMinorVersion
              let version = r.uint8(),
              let rawID = r.uint8(),
              let uid = r.uint64(),
              let time = r.float(),
              let frame = r.uint32(),
              r.uint32() != nil,           // overallFrameIdentifier
              let playerIdx = r.uint8(),
              r.uint8() != nil             // secondaryPlayerCarIndex
        else { return nil }
        guard let id = PacketID(rawValue: rawID),
              let packetFormat = PacketFormat(rawValue: format)
        else { return nil }

        self.format = packetFormat
        self.gameYear = year
        self.packetVersion = version
        self.packetID = id
        self.sessionUID = uid
        self.sessionTime = time
        self.frameIdentifier = frame
        self.playerCarIndex = Int(playerIdx)
    }
}

/// Packet ID 6 - CarTelemetryData (arac basina F1 26'da 59, F1 25'te 60 byte)
struct CarTelemetry {

    var speedKPH: Int = 0
    var throttle: Float = 0
    var steer: Float = 0
    var brake: Float = 0
    var gear: Int = 0
    var engineRPM: Int = 0
    var revLightsPercent: Int = 0
    var revLightsBits: UInt16 = 0
    var brakeTemps: [Int] = [0, 0, 0, 0]
    var tyreSurfaceTemps: [Int] = [0, 0, 0, 0]
    var tyreInnerTemps: [Int] = [0, 0, 0, 0]
    var engineTemp: Int = 0
    var tyrePressures: [Float] = [0, 0, 0, 0]
    /// Yalnizca F1 25: DRS acik mi. 2026 kurallarinda bu alan kullanilmaz.
    var drsActive: Bool = false

    init() {}

    init?(data: Data, carIndex: Int, format: PacketFormat) {
        let stride = format.telemetryStride
        var r = ByteReader(data, offset: PacketHeader.size + carIndex * stride)
        guard r.remaining >= stride else { return nil }
        guard let speed = r.uint16(),
              let throttle = r.float(),
              let steer = r.float(),
              let brake = r.float(),
              r.uint8() != nil,             // clutch
              let gear = r.int8(),
              let rpm = r.uint16(),
              let drs = r.uint8(),          // F1 25'te DRS; F1 26'da kullanilmaz
              let revPercent = r.uint8(),
              let revBits = r.uint16()
        else { return nil }

        self.speedKPH = Int(speed)
        self.throttle = throttle
        self.steer = steer
        self.brake = brake
        self.gear = Int(gear)
        self.engineRPM = Int(rpm)
        self.revLightsPercent = Int(revPercent)
        self.revLightsBits = revBits
        self.drsActive = !format.hasActiveAero && drs == 1

        var brakes: [Int] = []
        for _ in 0..<4 { guard let v = r.uint16() else { return nil }; brakes.append(Int(v)) }
        var surface: [Int] = []
        for _ in 0..<4 { guard let v = r.uint8() else { return nil }; surface.append(Int(v)) }
        var inner: [Int] = []
        for _ in 0..<4 { guard let v = r.uint8() else { return nil }; inner.append(Int(v)) }
        // Motor sicakligi: F1 26'da tek bayt, F1 25'te iki bayt.
        let engineTemp: Int
        if format.hasActiveAero {
            guard let v = r.uint8() else { return nil }
            engineTemp = Int(v)
        } else {
            guard let v = r.uint16() else { return nil }
            engineTemp = Int(v)
        }
        var pressures: [Float] = []
        for _ in 0..<4 { guard let v = r.float() else { return nil }; pressures.append(v) }

        self.brakeTemps = brakes
        self.tyreSurfaceTemps = surface
        self.tyreInnerTemps = inner
        self.engineTemp = engineTemp
        self.tyrePressures = pressures
    }
}

/// Packet ID 16 - CarTelemetry2Data (arac basina 10 byte, paket 269 byte).
/// 2026 kurallari: DRS yerine aktif aero (X/Z mode) + Overtake (manual override).
struct CarTelemetry2 {
    static let stride = 10

    enum AeroMode: UInt8 { case corner = 0, straight = 1 }

    var aeroMode: AeroMode = .corner
    var aeroAvailable: Bool = false
    var aeroActivationDistance: Int = 0
    var overtakeAvailable: Bool = false
    var overtakeActive: Bool = false
    var overtakeActivationDistance: Int = 0
    var is2026Regulations: Bool = false
    var drivingWrongWay: Bool = false

    init() {}

    init?(data: Data, carIndex: Int) {
        var r = ByteReader(data, offset: PacketHeader.size + carIndex * Self.stride)
        guard r.remaining >= Self.stride else { return nil }
        guard let mode = r.uint8(),
              let aeroAvail = r.uint8(),
              let aeroDist = r.uint16(),
              let otAvail = r.uint8(),
              let otActive = r.uint8(),
              let otDist = r.uint16(),
              let regs = r.uint8(),
              let wrongWay = r.uint8()
        else { return nil }

        self.aeroMode = AeroMode(rawValue: mode) ?? .corner
        self.aeroAvailable = aeroAvail == 1
        self.aeroActivationDistance = Int(aeroDist)
        self.overtakeAvailable = otAvail == 1
        self.overtakeActive = otActive == 1
        self.overtakeActivationDistance = Int(otDist)
        self.is2026Regulations = regs == 1
        self.drivingWrongWay = wrongWay == 1
    }
}

/// Packet ID 7 - CarStatusData (arac basina 59 byte, paket 1445 byte).
/// Faz 1 icin sadece rev bar ve limiter isigi gereken alanlari okuyoruz.
struct CarStatus {

    var pitLimiterOn: Bool = false
    var fuelRemainingLaps: Float = 0
    var maxRPM: Int = 15000
    var idleRPM: Int = 4000
    var maxGears: Int = 8
    /// ERS deposundaki enerji (Joule). Tam depo 4 MJ.
    var ersStoreEnergy: Float = 0
    var ersDeployMode: Int = 0
    /// -1 bilinmiyor, 0 yok, 1 yesil, 2 mavi, 3 sari
    var fiaFlag: Int = -1
    /// Bu turda toplanan ve harcanan ERS enerjisi (Joule) ile tur basina limit.
    var ersHarvestedThisLap: Float = 0
    var ersHarvestLimitPerLap: Float = 0
    var ersDeployedThisLap: Float = 0
    /// Yalnizca F1 25: DRS kullanilabilir mi.
    var drsAllowed: Bool = false

    init() {}

    init?(data: Data, carIndex: Int, format: PacketFormat) {
        let stride = format.statusStride
        var r = ByteReader(data, offset: PacketHeader.size + carIndex * stride)
        guard r.remaining >= stride else { return nil }
        r.skip(4)                            // tractionControl, abs, fuelMix, frontBrakeBias
        guard let limiter = r.uint8() else { return nil }
        r.skip(8)                            // fuelInTank, fuelCapacity
        guard let fuelLaps = r.float(),
              let maxRPM = r.uint16(),
              let idleRPM = r.uint16(),
              let maxGears = r.uint8()
        else { return nil }
        guard let drsAllowed = r.uint8() else { return nil }
        r.skip(5)                            // drsActivationDistance, lastik bilgileri
        guard let flag = r.int8() else { return nil }
        r.skip(8)                            // enginePowerICE, enginePowerMGUK
        guard let ersStore = r.float(),
              let deployMode = r.uint8(),
              let harvestMGUK = r.float(),
              let harvestMGUH = r.float()
        else { return nil }
        // Tur basina toplama limiti yalnizca F1 26'da var.
        var harvestLimit: Float = 0
        if format.hasActiveAero {
            guard let limit = r.float() else { return nil }
            harvestLimit = limit
        }
        guard let deployed = r.float() else { return nil }

        self.pitLimiterOn = limiter == 1
        self.fuelRemainingLaps = fuelLaps
        self.maxRPM = Int(maxRPM)
        self.idleRPM = Int(idleRPM)
        self.maxGears = Int(maxGears)
        self.ersStoreEnergy = ersStore
        self.ersDeployMode = Int(deployMode)
        self.fiaFlag = Int(flag)
        self.ersHarvestedThisLap = harvestMGUK + harvestMGUH
        self.ersHarvestLimitPerLap = harvestLimit
        self.ersDeployedThisLap = deployed
        self.drsAllowed = !format.hasActiveAero && drsAllowed == 1
    }
}

/// Packet ID 2 - LapData (arac basina 57 byte, paket 1399 byte)
struct LapData {
    /// Iki bicimde de arac basina 57 byte.
    static let stride = 57

    var lastLapTimeMS: Int = 0
    var currentLapTimeMS: Int = 0
    /// Tamamlanan sektor sureleri (ms). Sektor gecilmeden 0 gelir.
    var sector1MS: Int = 0
    var sector2MS: Int = 0
    /// Turun basindan bu yana kat edilen mesafe (m); cizgiyi gecmeden negatif.
    var lapDistance: Float = 0
    var deltaToCarInFrontMS: Int = 0
    var deltaToCarInFrontMinutes: Int = 0
    var carPosition: Int = 0
    var currentLapNum: Int = 0
    var sector: Int = 0
    var currentLapInvalid: Bool = false

    init?(data: Data, carIndex: Int, format: PacketFormat = .f126) {
        var r = ByteReader(data, offset: PacketHeader.size + carIndex * format.lapStride)
        guard r.remaining >= format.lapStride else { return nil }
        guard let lastLap = r.uint32(),
              let currentLap = r.uint32()
        else { return nil }
        guard let s1MS = r.uint16(),
              let s1Minutes = r.uint8(),
              let s2MS = r.uint16(),
              let s2Minutes = r.uint8(),
              let frontMS = r.uint16(),
              let frontMinutes = r.uint8()
        else { return nil }
        r.skip(3)                                  // deltaToRaceLeader
        guard let distance = r.float() else { return nil }
        r.skip(8)                                  // totalDistance, safetyCarDelta
        guard let position = r.uint8(),
              let lapNum = r.uint8(),
              r.uint8() != nil,                    // pitStatus
              r.uint8() != nil,                    // numPitStops
              let sector = r.uint8(),
              let invalid = r.uint8()
        else { return nil }

        self.lastLapTimeMS = Int(lastLap)
        self.currentLapTimeMS = Int(currentLap)
        self.sector1MS = Int(s1Minutes) * 60_000 + Int(s1MS)
        self.sector2MS = Int(s2Minutes) * 60_000 + Int(s2MS)
        self.lapDistance = distance
        self.deltaToCarInFrontMS = Int(frontMS)
        self.deltaToCarInFrontMinutes = Int(frontMinutes)
        self.carPosition = Int(position)
        self.currentLapNum = Int(lapNum)
        self.sector = Int(sector)
        self.currentLapInvalid = invalid == 1
    }
}

/// Packet ID 4 - ParticipantData (arac basina 60 byte, paket 1470 byte).
/// Bes saniyede bir gelir; isimler ve takim renkleri buradan.
struct Participant {
    var name: String = ""
    var raceNumber: Int = 0
    var teamColour: (red: Double, green: Double, blue: Double)?

    /// Soyadi: yayin grafiklerindeki gibi tek kelime gosterilir.
    var surname: String {
        name.split(separator: " ").last.map(String.init)?.uppercased() ?? name.uppercased()
    }
}

enum ParticipantsPacket {
    static func parse(_ data: Data, format: PacketFormat) -> [Participant] {
        var reader = ByteReader(data, offset: PacketHeader.size)
        guard reader.uint8() != nil else { return [] }      // m_numActiveCars

        let stride = format.participantStride
        // F1 26'da surucu / ag / takim kimlikleri uint16; F1 25'te uint8.
        let idBytes = format.hasActiveAero ? 8 : 5
        var result: [Participant] = []
        for index in 0..<format.cars {
            var r = ByteReader(data, offset: PacketHeader.size + 1 + index * stride)
            guard r.remaining >= stride else { break }
            r.skip(idBytes)                                  // ai, driverId, networkId, teamId, myTeam
            guard let raceNumber = r.uint8() else { break }
            r.skip(1)                                        // nationality

            var bytes: [UInt8] = []
            for _ in 0..<32 {
                guard let byte = r.uint8() else { break }
                if byte != 0 { bytes.append(byte) }
            }
            r.skip(5)                                        // telemetry, names, techLevel, platform
            guard let colourCount = r.uint8() else { break }

            var colour: (Double, Double, Double)?
            if colourCount > 0, let red = r.uint8(), let green = r.uint8(), let blue = r.uint8() {
                colour = (Double(red) / 255, Double(green) / 255, Double(blue) / 255)
            }

            var participant = Participant()
            participant.name = String(decoding: bytes, as: UTF8.self)
            participant.raceNumber = Int(raceNumber)
            participant.teamColour = colour
            result.append(participant)
        }
        return result
    }
}

extension LapData {
    /// Butun araclarin yaris pozisyonu; onundeki ve arkandakini bulmak icin.
    static func positions(in data: Data, format: PacketFormat) -> [Int] {
        (0..<format.cars).map { index in
            var r = ByteReader(data, offset: PacketHeader.size + index * LapData.stride + 32)
            return Int(r.uint8() ?? 0)
        }
    }
}

/// Packet ID 3 - Event. Dort harflik kod ve ardindan olaya ozel alanlar.
enum GameEvent {
    case startLights(count: Int)
    case lightsOut
    case other(String)

    init?(data: Data) {
        var r = ByteReader(data, offset: PacketHeader.size)
        var code = ""
        for _ in 0..<4 {
            guard let byte = r.uint8() else { return nil }
            code.append(Character(UnicodeScalar(byte)))
        }
        switch code {
        case "STLG":
            guard let lights = r.uint8() else { return nil }
            self = .startLights(count: Int(lights))
        case "LGOT":
            self = .lightsOut
        default:
            self = .other(code)
        }
    }
}

/// Packet ID 0 - Motion (arac basina 54 byte). Pist haritasi ve G kuvveti
/// icin oyuncunun dunya konumu ve ivmeleri.
struct CarMotion {

    var worldX: Float = 0
    var worldY: Float = 0
    var worldZ: Float = 0
    var speedMS: Float = 0
    var yaw: Float = 0
    /// G kuvvetleri (g biriminde; paket 1000 ile carpilmis int16 tasir).
    var gLateral: Float = 0
    var gLongitudinal: Float = 0

    init() {}

    init?(data: Data, carIndex: Int, format: PacketFormat) {
        let stride = format.motionStride
        var r = ByteReader(data, offset: PacketHeader.size + carIndex * stride)
        guard r.remaining >= stride else { return nil }
        guard let x = r.float(), let y = r.float(), let z = r.float(),
              let vx = r.float(), let vy = r.float(), let vz = r.float()
        else { return nil }
        r.skip(12)                                  // forward/right yon vektorleri
        // G kuvvetleri: F1 26'da 1000 ile carpilmis int16, F1 25'te float.
        let lateral: Float, longitudinal: Float
        if format.hasActiveAero {
            guard let gLat = r.uint16(), let gLong = r.uint16() else { return nil }
            r.skip(2)                               // gForceVertical
            lateral = Float(Int16(bitPattern: gLat)) / 1000
            longitudinal = Float(Int16(bitPattern: gLong)) / 1000
        } else {
            guard let gLat = r.float(), let gLong = r.float() else { return nil }
            r.skip(4)                               // gForceVertical
            lateral = gLat
            longitudinal = gLong
        }
        guard let yaw = r.float() else { return nil }
        worldX = x; worldY = y; worldZ = z
        speedMS = (vx * vx + vy * vy + vz * vz).squareRoot()
        self.yaw = yaw
        gLateral = lateral
        gLongitudinal = longitudinal
    }
}

/// Packet ID 1 - Session. Yalnizca pist ve hava bilgisi okunur.
struct SessionInfo: Equatable {
    var weather: Int = 0
    var trackTemperature: Int = 0
    var airTemperature: Int = 0
    var totalLaps: Int = 0
    var trackLength: Int = 0
    var sessionType: Int = 0
    var trackID: Int = -1
    /// Track name for games that send one instead of an F1 track id.
    var trackName: String?

    init() {}

    init?(data: Data) {
        var r = ByteReader(data, offset: PacketHeader.size)
        guard let weather = r.uint8(), let trackTemp = r.int8(), let airTemp = r.int8(),
              let totalLaps = r.uint8(), let length = r.uint16(),
              let type = r.uint8(), let track = r.int8()
        else { return nil }
        self.weather = Int(weather)
        trackTemperature = Int(trackTemp)
        airTemperature = Int(airTemp)
        self.totalLaps = Int(totalLaps)
        trackLength = Int(length)
        sessionType = Int(type)
        trackID = Int(track)
    }
}
