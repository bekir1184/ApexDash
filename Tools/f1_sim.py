#!/usr/bin/env python3
"""F1 26 UDP telemetri simulatoru.

Oyun acik olmadan dashboard'u test etmek icin gercek paket duzeninde
(packetFormat=2026) sahte veri gonderir.

Kullanim:
    python3 Tools/f1_sim.py 192.168.1.42      # iPhone'un IP'si
    python3 Tools/f1_sim.py 127.0.0.1         # Simulator icin
"""
import math
import socket
import struct
import sys
import time

CARS = 24
PLAYER = 0
RATE_HZ = 60

HEADER_FMT = "<HBBBBBQfIIBB"          # 29 byte
TELEMETRY_FMT = "<HfffBbHBBH4H4B4BB4f4B"   # 59 byte
TELEMETRY2_FMT = "<BBHBBHBB"          # 10 byte
LAPDATA_FMT = "<IIHBHBHBHBfffBBBBBBBBBBBBBBBHHBfB"  # 57 byte
STATUS_FMT = "<BBBBBfffHHBBHBBBbfffBffffB"  # 59 byte

MAX_RPM = 15000
IDLE_RPM = 4000


def header(packet_id, frame):
    return struct.pack(
        HEADER_FMT,
        2026,          # packetFormat
        26,            # gameYear
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


def lapdata_packet(frame, lap_time_ms, lap_num, delta_ms=340):
    payload = b""
    for car in range(CARS):
        if car == PLAYER:
            payload += struct.pack(
                LAPDATA_FMT,
                92_431, lap_time_ms,       # lastLapTime, currentLapTime
                31_205, 0,                 # sektor 1
                29_880, 0,                 # sektor 2
                delta_ms, 0,               # onundeki araca fark
                1_250, 0,                  # lidere fark
                1500.0, 12000.0, 0.0,      # lapDistance, totalDistance, safetyCarDelta
                4, lap_num, 0, 0, 1, 0,    # position, lap, pitStatus, pitStops, sector, invalid
                0, 0, 0, 0, 0,             # penalties, warnings, corner cuts, pens
                5, 4, 2,                   # gridPosition, driverStatus, resultStatus
                0, 0, 0, 0,                # pitLaneTimerActive, pitLaneTime, pitStopTimer
                312.5, 12,                 # speedTrap, speedTrapLap
            )
        else:
            payload += bytes(57)
    payload += struct.pack("<BB", 255, 255)
    return header(2, frame) + payload


def telemetry_packet(frame, speed, gear, rpm, throttle, brake, brake_temp=380, tyre_temp=98):
    percent = int(max(0, min(100, (rpm - IDLE_RPM) / (MAX_RPM - IDLE_RPM) * 100)))
    payload = b""
    for car in range(CARS):
        if car == PLAYER:
            payload += struct.pack(
                TELEMETRY_FMT,
                int(speed), throttle, 0.0, brake, 0, gear, int(rpm), 0,
                percent, rev_bits(percent),
                brake_temp + 40, brake_temp, brake_temp - 30, brake_temp - 60,
                tyre_temp, tyre_temp + 6, tyre_temp - 4, tyre_temp + 12,
                tyre_temp + 8, tyre_temp + 14, tyre_temp + 3, tyre_temp + 19, 110,
                *([23.5] * 4), *([0] * 4),
            )
        else:
            payload += bytes(59)
    payload += struct.pack("<BBb", 255, 255, 0)
    return header(6, frame) + payload


def telemetry2_packet(frame, overtake_ready, overtake_active, straight_mode):
    payload = b""
    for car in range(CARS):
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


def status_packet(frame, ers=4_000_000.0):
    payload = b""
    for car in range(CARS):
        if car == PLAYER:
            payload += struct.pack(
                STATUS_FMT,
                1, 0, 1, 55, 0,            # tc, abs, fuelMix, brakeBias, pitLimiter
                90.0, 110.0, 12.5,         # fuel
                MAX_RPM, IDLE_RPM, 8,      # maxRPM, idleRPM, maxGears
                0, 0,                      # drsAllowed, drsActivationDistance
                18, 18, 4, 1,              # actual/visual compound, tyre age, fia flag
                0.0, 0.0, ers,             # ICE, MGUK, ers store
                2,                         # ers deploy mode
                0.0, 0.0, 0.0, 0.0,        # harvest/deploy
                0,                         # networkPaused
            )
        else:
            payload += bytes(59)
    return header(7, frame) + payload


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 20777
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    print(f"F1 26 sim -> {target}:{port} @ {RATE_HZ} Hz  (Ctrl+C ile durdur)")

    frame = 0
    while True:
        t = frame / RATE_HZ
        # 8 saniyelik bir tur: vitesler yukari, sonra fren
        phase = (t % 8) / 8
        gear = min(8, max(1, int(phase * 9)))
        rpm = IDLE_RPM + (MAX_RPM - IDLE_RPM) * (0.35 + 0.65 * abs(math.sin(t * 2.2)))
        speed = 60 + 280 * phase
        throttle = 1.0 if phase < 0.72 else 0.0
        brake = 0.0 if phase < 0.72 else min(1.0, (phase - 0.72) * 6)

        brake_temp = int(260 + 640 * brake + 60 * math.sin(t))
        tyre_temp = int(88 + 26 * phase + 6 * math.sin(t * 0.7))
        sock.sendto(
            telemetry_packet(frame, speed, gear, rpm, throttle, brake, brake_temp, tyre_temp),
            (target, port),
        )
        if frame % 3 == 0:
            lap_time = int((t % 92) * 1000)
            delta_ms = int(1200 + 900 * math.sin(t * 0.35))
            sock.sendto(lapdata_packet(frame, lap_time, 26, delta_ms), (target, port))
            ers = 4_000_000.0 * (0.15 + 0.85 * abs(math.sin(t * 0.25)))
            sock.sendto(status_packet(frame, ers), (target, port))
            sock.sendto(
                telemetry2_packet(frame, overtake_ready=phase > 0.3,
                                  overtake_active=0.45 < phase < 0.6,
                                  straight_mode=phase > 0.35),
                (target, port),
            )
        frame += 1
        time.sleep(1 / RATE_HZ)


if __name__ == "__main__":
    main()
