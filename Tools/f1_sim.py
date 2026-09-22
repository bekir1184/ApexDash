#!/usr/bin/env python3
"""F1 25 / F1 26 UDP telemetry simulator.

Sends fake data in the real packet layout, to test Apex Dash without the game.
The app has the same simulation built in as Settings > Demo drive
(Sources/Games/F1/F1DemoDrive.swift).

Usage:
    python3 Tools/f1_sim.py 192.168.1.42            # the phone's IP
    python3 Tools/f1_sim.py 127.0.0.1               # iOS Simulator
    python3 Tools/f1_sim.py 127.0.0.1 --format=2025 # F1 25 packet layout
"""
import math
import socket
import struct
import sys
import time

# Format: 2026 (default) or 2025. The packet layouts differ in a few fields.
FORMAT = 2026
PLAYER = 0
RATE_HZ = 60


def is_2026():
    return FORMAT == 2026


def cars():
    return 24 if is_2026() else 22


HEADER_FMT = "<HBBBBBQfIIBB"          # 29 byte
# F1 26: one byte engine temperature (59). F1 25: two bytes (60).
TELEMETRY_FMT_2026 = "<HfffBbHBBH4H4B4BB4f4B"
TELEMETRY_FMT_2025 = "<HfffBbHBBH4H4B4BH4f4B"
TELEMETRY2_FMT = "<BBHBBHBB"          # 10 bytes, F1 26 only
# F1 26: driver/network/team ids are uint16 (60). F1 25: uint8 (57).
PARTICIPANT_FMT_2026 = "<BHHHBBB32sBBHBB12B"
PARTICIPANT_FMT_2025 = "<BBBBBBB32sBBHBB12B"
NAMES = ["Bekir Ersever", "Lewis Hamilton", "George Russell", "Max Verstappen",
         "Charles Leclerc", "Lando Norris"]
# the player is 4th, with 3rd ahead and 5th behind
POSITIONS = [4, 3, 5, 1, 2, 6]
LAPDATA_FMT = "<IIHBHBHBHBfffBBBBBBBBBBBBBBBHHBfB"  # 57 bytes, the same in both formats
# F1 26 has a per-lap harvest limit (59); F1 25 does not (55).
STATUS_FMT_2026 = "<BBBBBfffHHBBHBBBbfffBffffB"
STATUS_FMT_2025 = "<BBBBBfffHHBBHBBBbfffBfffB"
# F1 26: G forces as int16 multiplied by 1000 (54). F1 25: float (60).
MOTION_FMT_2026 = "<ffffffhhhhhhhhhfff"
MOTION_FMT_2025 = "<ffffffhhhhhhffffff"

MAX_RPM = 15000
IDLE_RPM = 4000

SESSION_HEAD_FMT = "<BbbBHBb"        # weather, trackTemp, airTemp, totalLaps, trackLength, sessionType, trackId
SESSION_SIZE = 926 - 29


class Track:
    """A closed circuit of straights and corners: distance -> position,
    curvature and target speed. Braking into corners, throttle out of them."""

    def __init__(self):
        # (length m, corner radius m or None for a straight, direction +1 left / -1 right)
        self.segments = [
            (700, None, 0), (90, 60, 1), (220, None, 0), (140, 120, -1), (380, None, 0),
            (80, 35, 1), (60, 35, 1), (300, None, 0), (200, 200, -1), (520, None, 0),
            (110, 45, -1), (250, None, 0), (160, 90, 1), (90, 50, 1), (600, None, 0),
            (140, 70, -1), (180, None, 0), (130, 55, 1), (150, 110, -1), (390, None, 0),
        ]
        self.length = sum(seg[0] for seg in self.segments)
        # Precompute positions at 1 m steps (spreading the closing error along the lap)
        pts, x, z, heading = [], 0.0, 0.0, 0.0
        curv = []
        for seg_len, radius, sign in self.segments:
            for _ in range(int(seg_len)):
                k = (sign / radius) if radius else 0.0
                heading += k
                x += math.cos(heading); z += math.sin(heading)
                pts.append((x, z)); curv.append(k)
        n = len(pts)
        for i, (px, pz) in enumerate(pts):
            f = i / n
            pts[i] = (px - x * f, pz - z * f)
        self.points, self.curv = pts, curv
        # Target speed from curvature, smoothed by braking and acceleration distances
        target = [min(330.0, 3.6 * math.sqrt(3.2 * 9.81 / abs(k))) if k else 330.0 for k in curv]
        for i in range(n - 2, -1, -1):
            target[i] = min(target[i], target[i + 1] + 0.55)      # braking (km/h per m)
        for i in range(1, n):
            target[i] = min(target[i], target[i - 1] + 0.22)      # acceleration
        self.target = target

    def at(self, distance):
        i = int(distance) % len(self.points)
        x, z = self.points[i]
        nx, nz = self.points[(i + 1) % len(self.points)]
        yaw = math.atan2(nz - z, nx - x)
        return x, z, yaw, self.curv[i], self.target[i]


TRACK = Track()


def motion_packet(frame, x, z, yaw, v_ms, g_lat, g_long):
    fmt = MOTION_FMT_2026 if is_2026() else MOTION_FMT_2025
    head = (
        x, 0.0, z,
        v_ms * math.cos(yaw), 0.0, v_ms * math.sin(yaw),
        int(math.cos(yaw) * 32767), 0, int(math.sin(yaw) * 32767),
        int(-math.sin(yaw) * 32767), 0, int(math.cos(yaw) * 32767),
    )
    # F1 26 carries G forces as integers multiplied by 1000.
    forces = ((int(g_lat * 1000), int(g_long * 1000), 1000) if is_2026()
              else (g_lat, g_long, 1.0))
    payload = b""
    for car in range(cars()):
        if car == PLAYER:
            payload += struct.pack(fmt, *head, *forces, yaw, 0.0, 0.0)
        else:
            payload += bytes(struct.calcsize(fmt))
    return header(0, frame) + payload


def session_packet(frame):
    head = struct.pack(SESSION_HEAD_FMT, 1, 41, 27, 20, int(TRACK.length), 10, 7)
    return header(1, frame) + head + bytes(SESSION_SIZE - len(head))


def header(packet_id, frame):
    return struct.pack(
        HEADER_FMT,
        FORMAT,        # packetFormat
        FORMAT % 100,  # gameYear
        1, 0,          # major, minor
        1,             # packetVersion
        packet_id,
        1234567890,    # sessionUID
        frame / RATE_HZ,
        frame,
        frame,
        PLAYER,
        255,
    )


def rev_bits(percent):
    lit = int(percent / 100 * 15)
    return sum(1 << i for i in range(lit))


def event_packet(frame, code, payload=b""):
    body = code.encode() + payload
    body += bytes(45 - 29 - len(body))
    return header(3, frame) + body


def participants_packet(frame):
    fmt = PARTICIPANT_FMT_2026 if is_2026() else PARTICIPANT_FMT_2025
    payload = struct.pack("<B", cars())
    for car in range(cars()):
        name = (NAMES[car] if car < len(NAMES) else f"Driver {car}").encode()[:31]
        colours = [0, 210, 190] + [0] * 9 if car == PLAYER else [220, 40, 40] + [0] * 9
        payload += struct.pack(
            fmt,
            0, car, 0, 1, 1 if car == PLAYER else 0, car + 1, 76,
            name, 1, 1, 0, 4, 1, *colours,
        )
    return header(4, frame) + payload


def lapdata_packet(frame, lap_time_ms, lap_num, delta_ms=340,
                   s1_ms=0, s2_ms=0, distance=0.0, sector=0, last_lap_ms=0):
    payload = b""
    for car in range(cars()):
        if car == PLAYER:
            payload += struct.pack(
                LAPDATA_FMT,
                last_lap_ms, lap_time_ms,  # lastLapTime, currentLapTime
                s1_ms % 60_000, s1_ms // 60_000,   # sector 1
                s2_ms % 60_000, s2_ms // 60_000,   # sector 2
                delta_ms, 0,               # gap to the car ahead
                1_250, 0,                  # gap to the leader
                distance, 12000.0, 0.0,    # lapDistance, totalDistance, safetyCarDelta
                POSITIONS[PLAYER], lap_num, 0, 0, sector, 0,  # position, lap, pit, stops, sector, invalid
                0, 0, 0, 0, 0,             # penalties, warnings, corner cuts, pens
                5, 4, 2,                   # gridPosition, driverStatus, resultStatus
                0, 0, 0, 0,                # pitLaneTimerActive, pitLaneTime, pitStopTimer
                312.5, 12,                 # speedTrap, speedTrapLap
            )
        else:
            position = POSITIONS[car] if car < len(POSITIONS) else car + 1
            other = bytearray(57)
            other[32] = position          # carPosition
            payload += bytes(other)
    payload += struct.pack("<BB", 255, 255)
    return header(2, frame) + payload


def telemetry_packet(frame, speed, gear, rpm, throttle, brake, brake_temp=380, tyre_temp=98,
                     steer=0.0, drs=0):
    percent = int(max(0, min(100, (rpm - IDLE_RPM) / (MAX_RPM - IDLE_RPM) * 100)))
    fmt = TELEMETRY_FMT_2026 if is_2026() else TELEMETRY_FMT_2025
    payload = b""
    for car in range(cars()):
        if car == PLAYER:
            payload += struct.pack(
                fmt,
                int(speed), throttle, steer, brake, 0, gear, int(rpm), drs,
                percent, rev_bits(percent),
                brake_temp + 40, brake_temp, brake_temp - 30, brake_temp - 60,
                tyre_temp, tyre_temp + 6, tyre_temp - 4, tyre_temp + 12,
                tyre_temp + 8, tyre_temp + 14, tyre_temp + 3, tyre_temp + 19, 110,
                *([23.5] * 4), *([0] * 4),
            )
        else:
            payload += bytes(struct.calcsize(fmt))
    payload += struct.pack("<BBb", 255, 255, 0)
    return header(6, frame) + payload


def telemetry2_packet(frame, overtake_ready, overtake_active, straight_mode):
    payload = b""
    for car in range(cars()):
        if car == PLAYER:
            payload += struct.pack(
                TELEMETRY2_FMT,
                1 if straight_mode else 0, 1, 0,
                1 if overtake_ready else 0, 1 if overtake_active else 0, 0,
                1, 0,
            )
        else:
            payload += bytes(10)
    return header(16, frame) + payload


def status_packet(frame, ers=4_000_000.0, limiter=0, flag=1,
                  harvest=0.0, deployed=0.0, drs_allowed=0):
    fmt = STATUS_FMT_2026 if is_2026() else STATUS_FMT_2025
    common = (
        1, 0, 1, 55, limiter,          # tc, abs, fuelMix, brakeBias, pitLimiter
        90.0, 110.0, 12.5,             # fuel
        MAX_RPM, IDLE_RPM, 8,          # maxRPM, idleRPM, maxGears
        drs_allowed, 0,                # drsAllowed, drsActivationDistance
        18, 18, 4, flag,               # actual/visual compound, tyre age, fia flag
        0.0, 0.0, ers,                 # ICE, MGUK, ers store
        2,                             # ers deploy mode
        harvest * 0.6, harvest * 0.4,  # harvested MGU-K, MGU-H
    )
    tail = (4_000_000.0, deployed, 0) if is_2026() else (deployed, 0)
    payload = b""
    for car in range(cars()):
        if car == PLAYER:
            payload += struct.pack(fmt, *common, *tail)
        else:
            payload += bytes(struct.calcsize(fmt))
    return header(7, frame) + payload


def main():
    global FORMAT
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for a in sys.argv[1:]:
        if a.startswith("--format"):
            FORMAT = int(a.split("=")[1]) if "=" in a else 2025
    target = args[0] if args else "127.0.0.1"
    port = int(args[1]) if len(args) > 1 else 20777
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    print(f"F1 {FORMAT % 100} sim -> {target}:{port} @ {RATE_HZ} Hz, "
          f"{cars()} cars  (Ctrl+C to stop)")

    frame = 0
    distance = 0.0
    speed = 80.0            # km/h
    lap_index = 0
    lap_start_t = 0.0
    last_lap_ms = 0
    s1_ms = s2_ms = 0
    prev_speed = speed
    while True:
        t = frame / RATE_HZ
        dt = 1 / RATE_HZ
        x, z, yaw, curv, v_target = TRACK.at(distance)
        # vary the pace per lap so comparisons are meaningful
        pace = 1 + 0.03 * math.sin(lap_index * 1.7)
        v_target = v_target / pace
        if speed < v_target:
            throttle, brake = 1.0, 0.0
            speed = min(v_target, speed + 45 * dt * (1 - speed / 360))
        else:
            throttle = 0.0 if v_target < speed - 4 else 0.4
            brake = min(1.0, 0.5 + (speed - v_target) / 30) if v_target < speed - 2 else 0.0
            speed = max(v_target, speed - (170 * brake + 12) * dt)
        v_ms = speed / 3.6
        distance += v_ms * dt
        if distance >= TRACK.length:
            distance -= TRACK.length
            last_lap_ms = int((t - lap_start_t) * 1000)
            lap_start_t = t
            lap_index += 1
            s1_ms = s2_ms = 0
        lap_time = int((t - lap_start_t) * 1000)
        sector = 0 if distance < TRACK.length / 3 else (1 if distance < 2 * TRACK.length / 3 else 2)
        if sector >= 1 and s1_ms == 0: s1_ms = lap_time
        if sector >= 2 and s2_ms == 0: s2_ms = lap_time - s1_ms

        gear = max(1, min(8, int(speed / 42) + 1))
        gear_span = 42
        rpm = IDLE_RPM + (MAX_RPM - IDLE_RPM) * ((speed - (gear - 1) * gear_span) / gear_span) * 0.9
        rpm = max(IDLE_RPM, min(MAX_RPM, rpm))
        g_lat = (v_ms * v_ms * curv) / 9.81
        steer = max(-1.0, min(1.0, curv * 40))
        g_long = ((speed - prev_speed) / 3.6 / dt) / 9.81
        prev_speed = speed
        phase = distance / TRACK.length

        brake_temp = int(260 + 640 * brake + 60 * math.sin(t))
        tyre_temp = int(88 + 26 * phase + 6 * math.sin(t * 0.7))
        # F1 25 DRS: open on straights at speed.
        drs = 1 if (not is_2026() and curv == 0 and speed > 200) else 0
        sock.sendto(
            telemetry_packet(frame, speed, gear, rpm, throttle, brake, brake_temp, tyre_temp,
                             steer, drs),
            (target, port),
        )
        sock.sendto(motion_packet(frame, x, z, yaw, v_ms, g_lat, g_long), (target, port))
        # first 6 seconds: five lights come on, then go out
        if t < 6:
            lights = min(5, int(t / 1.0))
            if lights > 0 and frame % 6 == 0:
                sock.sendto(event_packet(frame, "STLG", struct.pack("<B", lights)), (target, port))
        elif 6 <= t < 6.2 and frame % 6 == 0:
            sock.sendto(event_packet(frame, "LGOT"), (target, port))

        if frame % 120 == 0:
            sock.sendto(participants_packet(frame), (target, port))
            sock.sendto(session_packet(frame), (target, port))
        if frame % 3 == 0:
            delta_ms = int(1200 + 900 * math.sin(t * 0.35))
            sock.sendto(
                lapdata_packet(frame, lap_time, 20 + lap_index, delta_ms,
                               s1_ms, s2_ms, distance, sector, last_lap_ms),
                (target, port),
            )
            ers = 4_000_000.0 * (0.15 + 0.85 * abs(math.sin(t * 0.25)))
            # pit limiter for 5 seconds every 15 seconds
            limiter = 1 if (t % 15) < 5 else 0
            # flags: 10 s green, 5 s yellow, 5 s blue
            cycle = t % 20
            flag = 3 if cycle < 5 else (2 if cycle < 10 else 1)
            harvest = 4_000_000.0 * (0.2 + 0.6 * abs(math.sin(t * 0.15)))
            deployed = 4_000_000.0 * (0.1 + 0.5 * abs(math.cos(t * 0.2)))
            sock.sendto(status_packet(frame, ers, limiter, flag, harvest, deployed,
                                      drs_allowed=1 if drs else 0),
                        (target, port))
            # The active aero / overtake packet only exists in 2026.
            if is_2026():
                sock.sendto(
                    telemetry2_packet(frame, overtake_ready=phase > 0.3,
                                      overtake_active=0.45 < phase < 0.6,
                                      straight_mode=curv == 0 and speed > 200),
                    (target, port),
                )
        frame += 1
        time.sleep(1 / RATE_HZ)


if __name__ == "__main__":
    main()
