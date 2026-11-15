#!/usr/bin/env python3
"""Assetto Corsa Competizione broadcasting simulator.

Plays the game's side of the broadcasting protocol (version 4), to test Apex
Dash without ACC: it waits for the app to register, checks the connection
password, answers track data requests and then streams session and car
updates at the interval the app asked for. The app has the same simulation
built in as Settings > Demo drive (Sources/Games/ACC/ACCDemoDrive.swift); this
script also exercises the network path.

Usage:
    python3 Tools/acc_sim.py                    # listens on 9000, password "asd"
    python3 Tools/acc_sim.py --port=9001 --password=secret

In the app, pick ACC on the connection screen and enter this computer's IP
address and the same password.
"""
import math
import socket
import struct
import sys
import time

PORT = 9000
PASSWORD = "asd"
NO_TIME = 2**31 - 1
TRACK_NAME = "monza"


def acc_string(value):
    data = value.encode("utf-8")
    return struct.pack("<H", len(data)) + data


def read_string(data, offset):
    (length,) = struct.unpack_from("<H", data, offset)
    offset += 2
    return data[offset:offset + length].decode("utf-8", "replace"), offset + length


class Track:
    """An oval with two hairpins: straights, then 180 degree corners."""

    def __init__(self):
        self.straight = 1100.0
        self.radius = 90.0
        self.length = 2 * self.straight + 2 * math.pi * self.radius

    def at(self, d):
        d %= self.length
        s, r = self.straight, self.radius
        arc = math.pi * r
        if d < s:
            return d, 0.0, False
        if d < s + arc:
            a = (d - s) / r
            return s + r * math.sin(a), r - r * math.cos(a), True
        if d < 2 * s + arc:
            return s - (d - s - arc), 2 * r, False
        a = (d - 2 * s - arc) / r
        return -r * math.sin(a), r + r * math.cos(a), True


def lap_info(time_ms, car, splits):
    splits = (list(splits) + [None, None, None])[:3]
    data = struct.pack("<iHHB", NO_TIME if time_ms is None else time_ms, car, 0, 3)
    for split in splits:
        data += struct.pack("<i", NO_TIME if split is None else split)
    return data + struct.pack("<BBBB", 0, 1, 0, 0)


def registration_result(connection_id, success, error=""):
    return struct.pack("<BiBB", 1, connection_id, 1 if success else 0, 1) + acc_string(error)


def track_data(connection_id, track):
    return (struct.pack("<Bi", 5, connection_id) + acc_string(TRACK_NAME)
            + struct.pack("<ii", 0, int(track.length)) + struct.pack("<BB", 0, 0))


def realtime_update(session_ms, best_ms):
    data = struct.pack("<BHHBBffi", 2, 0, 0, 0, 5, session_ms, 3_600_000, 0)
    data += acc_string("Drivable") + acc_string("Chase") + acc_string("Basic HUD")
    data += struct.pack("<BfBBBBB", 0, 14 * 3_600_000, 22, 29, 2, 0, 0)
    return data + lap_info(best_ms, 0, [])


def car_update(car, gear, x, y, kmh, position, spline, laps, last, best, current):
    data = struct.pack("<BHHBBfffBHHHHfHi", 3, car, 0, 1, gear + 2, x, y, 0.0, 1,
                       int(kmh), position, position, position, spline, laps, 0)
    return data + lap_info(best, car, []) + lap_info(last[0], car, last[1]) + lap_info(current[0], car, current[1])


def main():
    sys.stdout.reconfigure(line_buffering=True)
    global PORT, PASSWORD
    for arg in sys.argv[1:]:
        if arg.startswith("--port="):
            PORT = int(arg.split("=", 1)[1])
        elif arg.startswith("--password="):
            PASSWORD = arg.split("=", 1)[1]

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", PORT))
    sock.setblocking(False)
    print(f"ACC simulator on UDP {PORT}, password '{PASSWORD}'. Waiting for Apex Dash to register...")

    track = Track()
    client, interval, connection_id = None, 0.05, 0
    distance, speed, laps = 0.0, 0.0, 0
    lap_start = time.time()
    last_ms, best_ms, splits = None, None, []
    start = time.time()
    next_send = time.time()

    while True:
        try:
            while True:
                data, address = sock.recvfrom(2048)
                kind = data[0]
                if kind == 1:                       # REGISTER_COMMAND_APPLICATION
                    name, offset = read_string(data, 2)
                    password, offset = read_string(data, offset)
                    (interval_ms,) = struct.unpack_from("<i", data, offset)
                    if password != PASSWORD:
                        sock.sendto(registration_result(0, False, "Wrong password"), address)
                        print(f"Refused {name} at {address[0]}: wrong password")
                        continue
                    connection_id += 1
                    client, interval = address, max(interval_ms, 10) / 1000
                    sock.sendto(registration_result(connection_id, True), address)
                    print(f"Registered {name} at {address[0]}:{address[1]}, every {interval_ms} ms")
                elif kind == 11 and client:         # REQUEST_TRACK_DATA
                    sock.sendto(track_data(connection_id, track), address)
                elif kind == 9:                     # UNREGISTER
                    print("Client unregistered")
                    client = None
        except BlockingIOError:
            pass

        now = time.time()
        if now < next_send:
            time.sleep(min(0.005, next_send - now))
            continue
        dt = interval
        next_send += interval

        x, y, corner = track.at(distance)
        target = 120 if corner else 265
        speed = min(target, speed + 26 * dt) if speed < target else max(target, speed - 95 * dt)
        distance += speed / 3.6 * dt
        lap_ms = int((now - lap_start) * 1000)
        third = track.length / 3
        if len(splits) < 2 and distance >= third * (len(splits) + 1):
            splits.append(lap_ms - sum(splits))
        if distance >= track.length:
            distance -= track.length
            last_ms = lap_ms
            best_ms = lap_ms if best_ms is None else min(best_ms, lap_ms)
            print(f"Lap {laps + 1}: {lap_ms / 1000:.3f}s")
            laps += 1
            lap_start = now
            splits = []
            lap_ms = 0

        if not client:
            continue
        gear = 1 if speed < 1 else max(1, min(6, int(speed / 48) + 1))
        packets = [realtime_update((now - start) * 1000, best_ms),
                   car_update(0, gear, x, y, speed, 1, distance / track.length, laps,
                              (last_ms, []), best_ms, (lap_ms, splits))]
        for packet in packets:
            sock.sendto(packet, client)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
