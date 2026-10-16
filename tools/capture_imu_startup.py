"""Receive aircraft USB logs and record CRC, revision, PWM and task timing."""
import argparse
import json
import math
from pathlib import Path
import re
import struct
import sys
import time

import serial
from serial.tools import list_ports

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser()
parser.add_argument("--port", default="COM4")
parser.add_argument("--seconds", type=float, default=15)
parser.add_argument("--record-stem", default="imu")
parser.add_argument("--expected-revision", type=int, default=1701)
args = parser.parse_args()
if not re.fullmatch(r"[a-z][a-z0-9_]*", args.record_stem):
    raise ValueError("Record stem must contain only lowercase letters, digits and underscores.")
root = Path(__file__).resolve().parents[1]
if args.seconds <= 0 or args.seconds > 60:
    raise ValueError("Capture must be between 0 and 60 seconds.")
devices = [p for p in list_ports.comports() if p.device == args.port
           and (p.serial_number or "").upper() == "70:AF:09:DF:A6:C4"]
if len(devices) != 1:
    raise RuntimeError("USB port does not match the configured aircraft.")
link = serial.Serial()
link.port, link.baudrate, link.timeout = args.port, 921600, .05
link.dtr, link.rts = False, False
link.open()
link.dtr = True
data = bytearray()
end = time.monotonic() + args.seconds
try:
    while time.monotonic() < end:
        data.extend(link.read(8192))
finally:
    link.close()
folder = root / "logs"
folder.mkdir(exist_ok=True)
file = folder / f"{args.record_stem}400_startup_{args.port}.bin"
file.write_bytes(data)


def crc16(payload):
    crc = 0xFFFF
    for value in payload:
        crc ^= value << 8
        for _ in range(8):
            crc = ((crc << 1) ^ (0x1021 if crc & 0x8000 else 0)) & 0xFFFF
    return crc


frames = {"SFI8": 0, "SFIX": 0, "SFIY": 0}
bad = {key: 0 for key in frames}
revisions, builds, modes = set(), set(), set()
times = []
max_pwm = 0
reserved_zero = True
finite_estimates = True
finite_altitude = True
finite_bias = True
finite_control_diagnostics = True
heights, biases, vertical_velocities = [], [], []
quaternion_norms = []
for magic, length in ((b"SFI8", 190), (b"SFIX", 190), (b"SFIY", 246)):
    start = 0
    while True:
        start = data.find(magic, start)
        if start < 0:
            break
        packet = data[start:start + length]
        start += 1
        if len(packet) != length:
            continue
        if crc16(packet[:-2]) != struct.unpack_from("<H", packet, length - 2)[0]:
            bad[magic.decode()] += 1
            continue
        frames[magic.decode()] += 1
        if magic == b"SFI8":
            builds.add(struct.unpack_from("<I", packet, 176)[0])
            modes.add(packet[109])
            times.append(struct.unpack_from("<I", packet, 6)[0] / 1000)
            height = struct.unpack_from("<f", packet, 91)[0]
            finite_altitude = finite_altitude and math.isfinite(height)
            heights.append(height)
            # Diagnostics 7 and 8 contain the estimated vertical velocity.
            encoded_velocity = struct.unpack_from("<h", packet, 124)[0]
            finite_altitude = finite_altitude and encoded_velocity != -32768
            if encoded_velocity != -32768:
                vertical_velocities.append(encoded_velocity / 1000)
        else:
            builds.add(struct.unpack_from("<I", packet, 10)[0])
            revisions.add(struct.unpack_from("<I", packet, 14)[0])
        if magic == b"SFIX":
            diagnostics = struct.unpack_from("<17f", packet, 18)
            finite_control_diagnostics = finite_control_diagnostics and all(
                math.isfinite(value) for value in diagnostics)
            max_pwm = max(max_pwm, *packet[126:130])
            reserved_zero = reserved_zero and packet[149] == 0 and packet[153] == 0
            modes.add(packet[155])
        elif magic == b"SFIY":
            sensor_diagnostics = struct.unpack_from("<8f", packet, 18)
            finite_bias = finite_bias and all(math.isfinite(value) for value in sensor_diagnostics)
            biases.append(sensor_diagnostics[1])
            values = struct.unpack_from("<10f", packet, 50)
            finite_estimates = finite_estimates and all(abs(x) < float("inf") for x in values)
            quaternion_norms.append(sum(x*x for x in values[6:10]))
tasks = []
for match in re.finditer(rb"SFTASK n=(\d+) mean_us=(\d+) max_us=(\d+) over=(\d+) missed=(\d+)", data):
    tasks.append(dict(zip(("n", "mean_us", "max_us", "over", "missed"), map(int, match.groups()))))
task_samples = sum(task["n"] for task in tasks)
timing = {
    "SampleCount": task_samples, "StepBudgetMicroseconds": 2500,
    "MeanMicroseconds": sum(task["n"] * task["mean_us"] for task in tasks) / task_samples
        if task_samples else None,
    "MaximumMicroseconds": max((task["max_us"] for task in tasks), default=None),
    "DeadlineExceededCount": sum(task["over"] for task in tasks),
    "MissedTickCount": max((task["missed"] for task in tasks), default=None),
    "AllObservedTasksWithinBudget": bool(tasks) and all(
        task["over"] == 0 and task["max_us"] <= 2500 and task["missed"] == 0 for task in tasks),
}
unit_quaternions = bool(quaternion_norms) and all(abs(value - 1) < .005 for value in quaternion_norms)
report = {
    "Port": args.port, "BaudRate": 921600, "CaptureSeconds": args.seconds,
    "CapturedBytes": len(data), "Frames": frames, "CRCErrors": bad,
    "BuildIDs": sorted(builds), "FirmwareRevisions": sorted(revisions), "ObservedModes": sorted(modes),
    "ReservedFieldsZero": reserved_zero, "MaximumAppliedPWMCount": max_pwm,
    "FiniteFilteredSensorsAndQuaternion": finite_estimates,
    "FiniteAltitudeAndVelocity": finite_altitude and bool(heights) and bool(vertical_velocities),
    "FiniteSensorDiagnosticsAndBias": finite_bias and bool(biases),
    "FiniteControlDiagnostics": finite_control_diagnostics,
    "HeightRange": [min(heights), max(heights)] if heights else [],
    "VerticalVelocityRange": [min(vertical_velocities), max(vertical_velocities)] if vertical_velocities else [],
    "AltitudeBiasRange": [min(biases), max(biases)] if biases else [],
    "QuaternionNormRange": [min(quaternion_norms), max(quaternion_norms)] if quaternion_norms else [],
    "UnitQuaternions": unit_quaternions,
    "FirmwareTimeSpanSeconds": max(times) - min(times) if times else 0,
    "TaskTiming": tasks, "TaskTimingSummary": timing,
    "CaptureFile": file.relative_to(root).as_posix(), "FlightCommandsSent": False,
    "PassedScope": "USB startup, log integrity and waiting outputs; timing is reported separately",
    "Passed": all(count > 0 for count in frames.values()) and not any(bad.values())
        and revisions == {args.expected_revision} and builds == {1401} and modes <= {0, 1, 3}
        and max_pwm == 0 and reserved_zero and finite_estimates and unit_quaternions
        and finite_altitude and finite_bias and finite_control_diagnostics
        and bool(heights) and bool(vertical_velocities) and bool(biases),
}
(root / "docs" / f"{args.record_stem}_usb_startup.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
if not report["Passed"]:
    raise RuntimeError("IMU USB startup verification failed; see saved record.")
deployment_file = root / "docs" / f"{args.record_stem}_aircraft_deployment.json"
deployment = json.loads(deployment_file.read_text(encoding="utf-8"))
deployment["usb_startup"] = report
deployment["usb_startup_verified"] = True
deployment_file.write_text(json.dumps(deployment, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("IMU400_USB_STARTUP_VERIFIED", flush=True)
