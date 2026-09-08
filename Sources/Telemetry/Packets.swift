import Foundation

/// F1 26 (F1 25 + 2026 Season Pack) UDP spesifikasyonu, packetFormat = 2026.
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

    let packetFormat: UInt16
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
        guard let id = PacketID(rawValue: rawID) else { return nil }

        self.packetFormat = format
        self.gameYear = year
        self.packetVersion = version
        self.packetID = id
        self.sessionUID = uid
        self.sessionTime = time
        self.frameIdentifier = frame
        self.playerCarIndex = Int(playerIdx)
    }
}

/// Packet ID 6 - CarTelemetryData (arac basina 59 byte, paket 1448 byte)
struct CarTelemetry {
    static let stride = 59

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

    init?(data: Data, carIndex: Int) {
        var r = ByteReader(data, offset: PacketHeader.size + carIndex * Self.stride)
        guard r.remaining >= Self.stride else { return nil }
        guard let speed = r.uint16(),
              let throttle = r.float(),
              let steer = r.float(),
              let brake = r.float(),
              r.uint8() != nil,             // clutch
              let gear = r.int8(),
              let rpm = r.uint16(),
              r.uint8() != nil,             // m_drs - 2026 kurallarinda kullanilmiyor
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

        var brakes: [Int] = []
        for _ in 0..<4 { guard let v = r.uint16() else { return nil }; brakes.append(Int(v)) }
        var surface: [Int] = []
        for _ in 0..<4 { guard let v = r.uint8() else { return nil }; surface.append(Int(v)) }
        var inner: [Int] = []
        for _ in 0..<4 { guard let v = r.uint8() else { return nil }; inner.append(Int(v)) }
        guard let engineTemp = r.uint8() else { return nil }
        var pressures: [Float] = []
        for _ in 0..<4 { guard let v = r.float() else { return nil }; pressures.append(v) }

        self.brakeTemps = brakes
        self.tyreSurfaceTemps = surface
        self.tyreInnerTemps = inner
        self.engineTemp = Int(engineTemp)
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
    static let stride = 59

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

    init?(data: Data, carIndex: Int) {
        var r = ByteReader(data, offset: PacketHeader.size + carIndex * Self.stride)
        guard r.remaining >= Self.stride else { return nil }
        r.skip(4)                            // tractionControl, abs, fuelMix, frontBrakeBias
        guard let limiter = r.uint8() else { return nil }
        r.skip(8)                            // fuelInTank, fuelCapacity
        guard let fuelLaps = r.float(),
              let maxRPM = r.uint16(),
              let idleRPM = r.uint16(),
              let maxGears = r.uint8()
        else { return nil }
        r.skip(6)                            // drsAllowed, drsActivationDistance, lastik bilgileri
        guard let flag = r.int8() else { return nil }
        r.skip(8)                            // enginePowerICE, enginePowerMGUK
        guard let ersStore = r.float(),
              let deployMode = r.uint8()
        else { return nil }

        self.pitLimiterOn = limiter == 1
        self.fuelRemainingLaps = fuelLaps
        self.maxRPM = Int(maxRPM)
        self.idleRPM = Int(idleRPM)
        self.maxGears = Int(maxGears)
        self.ersStoreEnergy = ersStore
        self.ersDeployMode = Int(deployMode)
        self.fiaFlag = Int(flag)
    }
}

/// Packet ID 2 - LapData (arac basina 57 byte, paket 1399 byte)
struct LapData {
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

    init?(data: Data, carIndex: Int) {
        var r = ByteReader(data, offset: PacketHeader.size + carIndex * Self.stride)
        guard r.remaining >= Self.stride else { return nil }
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
