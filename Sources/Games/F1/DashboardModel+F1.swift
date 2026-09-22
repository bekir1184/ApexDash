import Foundation

/// Applies decoded F1 packets to the dashboard model.
extension DashboardModel {
    mutating func apply(_ t: CarTelemetry, format: PacketFormat) {
        usesDRS = !format.hasActiveAero
        drsActive = t.drsActive
        apply(t)
    }

    mutating func apply(_ t: CarTelemetry) {
        speedKPH = t.speedKPH
        gear = t.gear
        rpm = t.engineRPM
        throttle = t.throttle
        brake = t.brake
        revLightsPercent = t.revLightsPercent
        revLightsBits = t.revLightsBits
        tyreSurfaceTemps = t.tyreSurfaceTemps
        tyreInnerTemps = t.tyreInnerTemps
        brakeTemps = t.brakeTemps
        engineTemp = t.engineTemp
    }

    mutating func apply(_ l: LapData) {
        currentLapTimeMS = l.currentLapTimeMS
        lastLapTimeMS = l.lastLapTimeMS
        deltaToCarInFrontMS = l.deltaToCarInFrontMS
        currentLapNum = l.currentLapNum
        carPosition = l.carPosition
        currentLapInvalid = l.currentLapInvalid
        sector1MS = l.sector1MS
        sector2MS = l.sector2MS
    }

    mutating func apply(_ s: CarStatus) {
        maxRPM = s.maxRPM
        idleRPM = s.idleRPM
        maxGears = s.maxGears
        pitLimiterOn = s.pitLimiterOn
        // The store holds 4 MJ; a 0.05 % change filters out packet noise.
        let delta = s.ersStoreEnergy - ersStoreEnergy
        let threshold: Float = 2_000
        if delta > threshold { ersTrend = 1 }
        else if delta < -threshold { ersTrend = -1 }
        else if abs(delta) <= threshold / 4 { ersTrend = 0 }
        ersStoreEnergy = s.ersStoreEnergy
        ersDeployMode = s.ersDeployMode
        fuelRemainingLaps = s.fuelRemainingLaps
        fiaFlag = s.fiaFlag
        ersHarvestedThisLap = s.ersHarvestedThisLap
        ersHarvestLimitPerLap = s.ersHarvestLimitPerLap
        ersDeployedThisLap = s.ersDeployedThisLap
        drsAllowed = s.drsAllowed
    }

    mutating func apply(_ m: CarMotion) {
        gLateral = m.gLateral
        gLongitudinal = m.gLongitudinal
    }

    mutating func apply(_ t: CarTelemetry2) {
        aeroStraightMode = t.aeroMode == .straight
        aeroAvailable = t.aeroAvailable
        overtakeAvailable = t.overtakeAvailable
        overtakeActive = t.overtakeActive
        is2026Regulations = t.is2026Regulations
    }
}
