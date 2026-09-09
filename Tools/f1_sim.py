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
PARTICIPANT_FMT = "<BHHHBBB32sBBHBB12B"   # 60 byte
NAMES = ["Bekir Ersever", "Lewis Hamilton", "George Russell", "Max Verstappen",
         "Charles Leclerc", "Lando Norris"]
# oyuncu 4. sirada; onunde 3, arkasinda 5 var
POSITIONS = [4, 3, 5, 1, 2, 6]
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


def participants_packet(frame):
    payload = struct.pack("<B", CARS)
    for car in range(CARS):
        name = (NAMES[car] if car < len(NAMES) else f"Driver {car}").encode()[:31]
        colours = [0, 210, 190] + [0] * 9 if car == PLAYER else [220, 40, 40] + [0] * 9
        payload += struct.pack(
            PARTICIPANT_FMT,
            0, car, 0, 1, 1 if car == PLAYER else 0, car + 1, 76,
            name, 1, 1, 0, 4, 1, *colours,
        )
    return header(4, frame) + payload


def lapdata_packet(frame, lap_time_ms, lap_num, delta_ms=340,
                   s1_ms=0, s2_ms=0, distance=0.0, sector=0, last_lap_ms=0):
    payload = b""
    for car in range(CARS):
        if car == PLAYER:
            payload += struct.pack(
                LAPDATA_FMT,
                last_lap_ms, lap_time_ms,  # lastLapTime, currentLapTime
                s1_ms % 60_000, s1_ms // 60_000,   # sektor 1
                s2_ms % 60_000, s2_ms // 60_000,   # sektor 2
                delta_ms, 0,               # onundeki araca fark
                1_250, 0,                  # lidere fark
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


def status_packet(frame, ers=4_000_000.0, limiter=0, flag=1,
                  harvest=0.0, deployed=0.0):
    payload = b""
    for car in range(CARS):
        if car == PLAYER:
            payload += struct.pack(
                STATUS_FMT,
                1, 0, 1, 55, limiter,      # tc, abs, fuelMix, brakeBias, pitLimiter
                90.0, 110.0, 12.5,         # fuel
                MAX_RPM, IDLE_RPM, 8,      # maxRPM, idleRPM, maxGears
                0, 0,                      # drsAllowed, drsActivationDistance
                18, 18, 4, flag,           # actual/visual compound, tyre age, fia flag
                0.0, 0.0, ers,             # ICE, MGUK, ers store
                2,                         # ers deploy mode
                harvest * 0.6, harvest * 0.4, 4_000_000.0, deployed,  # harvestMGUK/H, limit, deployed
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
        if frame % 120 == 0:
            sock.sendto(participants_packet(frame), (target, port))
        if frame % 3 == 0:
            # 45 saniyelik tur; her turun temposu biraz farkli olsun ki
            # en iyi tura gore delta anlamli ciksin.
            lap_length = 45.0
            track_metres = 5000.0
            lap_index = int(t / lap_length)
            pace = 1 + 0.03 * math.sin(lap_index * 1.7)
            in_lap = t % lap_length
            lap_time = int(in_lap * 1000 * pace)
            distance = in_lap / lap_length * track_metres
            sector = 0 if distance < track_metres / 3 else (1 if distance < 2 * track_metres / 3 else 2)
            s1 = int(lap_length / 3 * 1000 * pace) if sector >= 1 else 0
            s2 = int(lap_length / 3 * 1000 * pace) if sector >= 2 else 0
            last_lap = int(lap_length * 1000 * (1 + 0.03 * math.sin((lap_index - 1) * 1.7))) if lap_index else 0
            delta_ms = int(1200 + 900 * math.sin(t * 0.35))
            sock.sendto(
                lapdata_packet(frame, lap_time, 20 + lap_index, delta_ms,
                               s1, s2, distance, sector, last_lap),
                (target, port),
            )
            ers = 4_000_000.0 * (0.15 + 0.85 * abs(math.sin(t * 0.25)))
            # her 15 saniyede 5 saniyeligine pit limiter
            limiter = 1 if (t % 15) < 5 else 0
            # bayraklar: 10 sn yesil, 5 sn sari, 5 sn mavi
            cycle = t % 20
            flag = 3 if cycle < 5 else (2 if cycle < 10 else 1)
            harvest = 4_000_000.0 * (0.2 + 0.6 * abs(math.sin(t * 0.15)))
            deployed = 4_000_000.0 * (0.1 + 0.5 * abs(math.cos(t * 0.2)))
            sock.sendto(status_packet(frame, ers, limiter, flag, harvest, deployed), (target, port))
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
