"""Receive aircraft USB logs and record CRC, revision, PWM and task timing."""
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import sys
import time

import serial
from serial.tools import list_ports

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser()
parser.add_argument("--port", default="COM4")
parser.add_argument("--device", choices=("aircraft", "receiver"), default="aircraft")
parser.add_argument("--expected-mac", default=None,
                    help="USB serial/MAC of your own device; defaults to the recorded development device.")
parser.add_argument("--seconds", type=float, default=15)
parser.add_argument("--record-stem", default="imu")
parser.add_argument("--expected-revision", type=int, default=1804)
parser.add_argument("--expected-horizontal-revision", type=int, default=None,
                    help="Expected SFIH revision when it differs from SFIX/SFIY.")
parser.add_argument("--horizontal", action="store_true")
parser.add_argument("--deployment-stem", default=None)
parser.add_argument("--reset", action="store_true", help="Reset the USB-only bench device before capture; no firmware is written.")
parser.add_argument("--stationary-bench", action="store_true", help="Check the confirmed level, stationary bench condition separately from packet integrity.")
parser.add_argument("--input-file", default=None, help="Re-analyse saved USB data without connecting to hardware.")
args = parser.parse_args()
if args.expected_horizontal_revision is not None and not args.horizontal:
    parser.error("--expected-horizontal-revision requires --horizontal.")
if not re.fullmatch(r"[a-z][a-z0-9_]*", args.record_stem):
    raise ValueError("Record stem must contain only lowercase letters, digits and underscores.")
deployment_stem = args.deployment_stem or args.record_stem
if not re.fullmatch(r"[a-z][a-z0-9_]*", deployment_stem):
    raise ValueError("Deployment stem must contain only lowercase letters, digits and underscores.")
root = Path(__file__).resolve().parents[1]
if args.seconds <= 0 or args.seconds > 60:
    raise ValueError("Capture must be between 0 and 60 seconds.")
expected_mac = {"aircraft": "70:AF:09:DF:A6:C4", "receiver": "10:51:DB:55:A1:60"}[args.device]
if args.expected_mac:
    expected_mac = args.expected_mac.upper()
devices = [p for p in list_ports.comports() if p.device == args.port
           and (p.serial_number or "").upper() == expected_mac]
if not args.input_file and len(devices) != 1:
    raise RuntimeError("USB port does not match the configured device.")
reset_transcript = ""
if args.reset and not args.input_file:
    # 電池・プロペラを外した確認済みのUSB机上試験。読み出しと再起動だけ。
    result = subprocess.run([sys.executable, "-m", "esptool", "--chip", "esp32s3",
                             "--port", args.port, "--after", "watchdog_reset", "chip_id"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    reset_transcript = result.stdout.decode("utf-8", errors="replace")
    print(reset_transcript, flush=True)
    (root / "logs").mkdir(exist_ok=True)
    (root / "logs" / f"{args.record_stem}_reset.log").write_text(reset_transcript, encoding="utf-8")
    result.check_returncode()
if args.input_file:
    file = (root / args.input_file).resolve()
    data = file.read_bytes()
else:
    link = serial.Serial()
    link.port, link.baudrate, link.timeout = args.port, 921600, .05
    link.dtr, link.rts = False, False
    open_deadline = time.monotonic() + 10
    while True:
        try:
            link.open()
            break
        except serial.SerialException:
            if not args.reset or time.monotonic() >= open_deadline:
                raise
            time.sleep(.1)
    link.dtr = True
    if not args.reset:
        warmup = time.monotonic() + 1
        while time.monotonic() < warmup:
            link.read(8192)  # 通常の接続確認では前回キューを流します。
        link.reset_input_buffer()
    # 再起動時は校正の冒頭を捨てず、時刻とサンプル数の増加を記録します。
    if args.device == "receiver":
        link.write(b"PING\n")  # 受信機のCHを問い合わせるだけで、機体操作は送りません。
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
if args.horizontal:
    frames["SFIH"] = 0
bad = {key: 0 for key in frames}
revisions, builds, modes = set(), set(), set()
revisions_by_packet = {name: set() for name in frames if name != "SFI8"}
expected_revisions = {name: args.expected_horizontal_revision
                      if name == "SFIH" and args.expected_horizontal_revision is not None
                      else args.expected_revision for name in revisions_by_packet}
times = []
max_pwm = 0
reserved_zero = True
finite_estimates = True
finite_altitude = True
finite_bias = True
finite_control_diagnostics = True
initialization_invalid_heights = 0
heights, biases, vertical_velocities = [], [], []
quaternion_norms = []
horizontal_values = []
horizontal_keys = set()
base_keys = set()
packet_keys = {key: set() for key in frames}
raw_ranges, flow_qualities, tilt_degrees = [], [], []
calibration_rows = []
reset_reasons = set()
packets = [(b"SFI8", 190), (b"SFIX", 190), (b"SFIY", 246)]
if args.horizontal:
    packets.append((b"SFIH", 182))
for magic, length in packets:
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
            base_keys.add((struct.unpack_from("<H",packet,4)[0], struct.unpack_from("<I",packet,6)[0],
                           struct.unpack_from("<I",packet,176)[0]))
            builds.add(struct.unpack_from("<I", packet, 176)[0])
            modes.add(packet[109])
            times.append(struct.unpack_from("<I", packet, 6)[0] / 1000)
            height = struct.unpack_from("<f", packet, 91)[0]
            if packet[109] > 1:
                finite_altitude = finite_altitude and math.isfinite(height) and packet[95] != 0
            elif not math.isfinite(height):
                initialization_invalid_heights += 1
            if math.isfinite(height):
                heights.append(height)
            # Diagnostics 7 and 8 contain the estimated vertical velocity.
            encoded_velocity = struct.unpack_from("<h", packet, 124)[0]
            if packet[109] > 1:
                finite_altitude = finite_altitude and encoded_velocity != -32768
            if encoded_velocity != -32768:
                vertical_velocities.append(encoded_velocity / 1000)
        else:
            builds.add(struct.unpack_from("<I", packet, 10)[0])
            revision = struct.unpack_from("<I", packet, 14)[0]
            revisions.add(revision)
            revisions_by_packet[magic.decode()].add(revision)
        build_offset = 176 if magic == b"SFI8" else 10
        packet_keys[magic.decode()].add((struct.unpack_from("<H", packet, 4)[0],
                                        struct.unpack_from("<I", packet, 6)[0],
                                        struct.unpack_from("<I", packet, build_offset)[0]))
        if magic == b"SFI8":
            raw_ranges.append(struct.unpack_from("<f", packet, 35)[0])
            flow_qualities.append(packet[49])
        if magic == b"SFIX":
            diagnostics = struct.unpack_from("<17f", packet, 18)
            finite_control_diagnostics = finite_control_diagnostics and all(
                math.isfinite(value) for value in diagnostics)
            max_pwm = max(max_pwm, *packet[126:130])
            reserved_zero = reserved_zero and packet[149] == 0 and packet[153] == 0
            modes.add(packet[155])
        elif magic == b"SFIY":
            revision = struct.unpack_from("<I", packet, 14)[0]
            if revision >= 1802:
                reset_reasons.add(packet[243])
            q = struct.unpack_from("<4f", packet, 74)
            projection = 1 - 2 * (q[1] * q[1] + q[2] * q[2])
            if math.isfinite(projection):
                tilt_degrees.append(math.degrees(math.acos(max(-1, min(1, projection)))))
            sensor_diagnostics = struct.unpack_from("<8f", packet, 18)
            filtered_accel = struct.unpack_from("<3f", packet, 50)
            calibration_rows.append({
                "TimeSeconds": struct.unpack_from("<I", packet, 6)[0] / 1000,
                "Count": int(sensor_diagnostics[7]),
                "GyroBiasRadps": list(sensor_diagnostics[3:6]),
                "AccelZBiasG": sensor_diagnostics[6],
                "VerticalAccelG": sensor_diagnostics[0],
                "FilteredAccelG": list(filtered_accel),
            })
            finite_bias = finite_bias and all(math.isfinite(value) for value in sensor_diagnostics)
            biases.append(sensor_diagnostics[1])
            values = struct.unpack_from("<10f", packet, 50)
            finite_estimates = finite_estimates and all(abs(x) < float("inf") for x in values)
            quaternion_norms.append(sum(x*x for x in values[6:10]))
        elif magic == b"SFIH":
            values = struct.unpack_from("<40f", packet, 18)
            horizontal_values.append(values)
            horizontal_keys.add((struct.unpack_from("<H",packet,4)[0], struct.unpack_from("<I",packet,6)[0],
                                 struct.unpack_from("<I",packet,10)[0]))
            reserved_zero = reserved_zero and packet[178:180] == b"\x00\x00"
tasks = []
for match in re.finditer(rb"SFTASK n=(\d+) mean_us=(\d+) max_us=(\d+) over=(\d+) missed=(\d+)", data):
    tasks.append(dict(zip(("n", "mean_us", "max_us", "over", "missed"), map(int, match.groups()))))
profiles=[]
for match in re.finditer(rb"SFPROFILE logger_max_us=(\d+) flow_motion_max_us=(\d+) horizontal_log_max_us=(\d+)",data):
    profiles.append(dict(zip(("LoggerMaxUs","FlowMotionMaxUs","HorizontalLoggerMaxUs"),map(int,match.groups()))))
task_samples = sum(task["n"] for task in tasks)
runtime_rows = []
for match in re.finditer(rb"SFRUNTIME reset_reason=(\d+) idle0_age_us=(\d+) idle1_age_us=(\d+) stack_min_bytes=(\d+) heap_bytes=(\d+) core=(\d+) idle_hook_status=(\d+)", data):
    runtime_rows.append(dict(zip(("ResetReason","Idle0AgeUs","Idle1AgeUs","StackMinimumBytes", "FreeHeapBytes","ControlCore","IdleHookStatus"),map(int,match.groups()))))
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
    "CapturedAtUTC": datetime.now(timezone.utc).isoformat(),
    "Device": args.device, "Port": args.port, "BaudRate": 921600, "CaptureSeconds": args.seconds,
    "CapturedBytes": len(data), "Frames": frames, "CRCErrors": bad,
    "BuildIDs": sorted(builds), "FirmwareRevisions": sorted(revisions), "ObservedModes": sorted(modes),
    "FirmwareRevisionsByPacket": {name: sorted(values) for name, values in revisions_by_packet.items()},
    "ExpectedFirmwareRevisionsByPacket": expected_revisions,
    "ReservedFieldsZero": reserved_zero, "MaximumAppliedPWMCount": max_pwm,
    "FiniteFilteredSensorsAndQuaternion": finite_estimates,
    "FiniteAltitudeAndVelocity": finite_altitude and bool(heights) and bool(vertical_velocities),
    "InitializationInvalidHeightSamples": initialization_invalid_heights,
    "InitializationHeightNote": "Modes 0/1 have no height before sensors and estimation are ready; modes >1 must be finite and valid.",
    "FiniteSensorDiagnosticsAndBias": finite_bias and bool(biases),
    "FiniteControlDiagnostics": finite_control_diagnostics,
    "HeightRange": [min(heights), max(heights)] if heights else [],
    "VerticalVelocityRange": [min(vertical_velocities), max(vertical_velocities)] if vertical_velocities else [],
    "AltitudeBiasRange": [min(biases), max(biases)] if biases else [],
    "QuaternionNormRange": [min(quaternion_norms), max(quaternion_norms)] if quaternion_norms else [],
    "RawToFRangeM": [min(raw_ranges), max(raw_ranges)] if raw_ranges else [],
    "FlowSQUALRange": [min(flow_qualities), max(flow_qualities)] if flow_qualities else [],
    "EstimatedTiltDegreesRange": [min(tilt_degrees), max(tilt_degrees)] if tilt_degrees else [],
    "UnitQuaternions": unit_quaternions,
    "FirmwareTimeSpanSeconds": max(times) - min(times) if times else 0,
    "FirmwareFirstTimeSeconds": times[0] if times else None,
    "FirmwareLastTimeSeconds": times[-1] if times else None,
    "TaskTiming": tasks, "TaskTimingSummary": timing,
    "ResetReasons": sorted(reset_reasons), "RuntimeDiagnostics": runtime_rows,
    "ProfileMaxima": {name:max(p[name] for p in profiles) for name in profiles[0]} if profiles else {},
    "CaptureFile": file.relative_to(root).as_posix(), "FlightCommandsSent": False,
    "FrameKeysMatchedToBase": {key: len(base_keys & keys) for key, keys in packet_keys.items()},
    "PassedScope": "USB packet integrity and zero waiting outputs only; actual boot, stationary health and timing have separate results",
    "Passed": all(count > 0 for count in frames.values()) and not any(bad.values())
        and all(revisions_by_packet[name] == {value} for name, value in expected_revisions.items())
        and builds == {1401} and modes <= {0, 1, 3}
        and max_pwm == 0 and reserved_zero and finite_estimates and unit_quaternions
        and finite_altitude and finite_bias and finite_control_diagnostics
        and bool(heights) and bool(vertical_velocities) and bool(biases),
}
boot_captured = bool(calibration_rows and times and times[0] < 5 and
                     min(row["Count"] for row in calibration_rows) < 800 and
                     max(row["Count"] for row in calibration_rows) == 800)
report["ResetRequested"] = args.reset
report["AnalysisOfSavedCapture"] = bool(args.input_file)
report["ActualBootAndCalibrationCaptured"] = boot_captured
report["CalibrationAtFirstPacket"] = calibration_rows[0] if calibration_rows else None
report["CalibrationAtLastPacket"] = calibration_rows[-1] if calibration_rows else None
settled = [row for row in calibration_rows if row["Count"] == 800 and
           row["TimeSeconds"] >= calibration_rows[-1]["TimeSeconds"] - 5]
if args.stationary_bench:
    report["StationaryBenchHealth"] = {
        "SettledSamples": len(settled),
        "ZOffsetMatchesRestingGravity": bool(settled) and all(
            abs(row["AccelZBiasG"] - row["FilteredAccelG"][2]) < .2 for row in settled),
        "UpperSurfaceUpGravity": bool(settled) and all(
            abs(row["FilteredAccelG"][2] + 1) < .25 for row in settled),
        "SmallGyroBias": bool(settled) and all(
            max(abs(x) for x in row["GyroBiasRadps"]) < .15 for row in settled),
        "SmallVerticalAcceleration": bool(settled) and all(abs(row["VerticalAccelG"]) < .2 for row in settled),
        "VelocityNotSaturated": bool(vertical_velocities) and all(abs(x) < 32.767 for x in vertical_velocities),
        "SmallStationaryVerticalVelocity": bool(vertical_velocities) and all(abs(x) < .25 for x in vertical_velocities),
    }
    report["StationaryBenchHealth"]["Passed"] = all(
        value for key, value in report["StationaryBenchHealth"].items() if key != "SettledSamples")
if args.device == "receiver":
    channels = {int(x) for x in re.findall(rb"PONG,(\d+)", data)}
    report["ReceiverChannels"] = sorted(channels)
    report["Passed"] = report["Passed"] and channels == {3}
if args.horizontal:
    finite = bool(horizontal_values) and all(math.isfinite(x) for row in horizontal_values for x in row)
    disabled = bool(horizontal_values) and all(row[16] == 0 and row[14] == 0 for row in horizontal_values)
    matched = len(base_keys & horizontal_keys)
    longest_valid = run = 0
    for row in horizontal_values:
        run = run + 1 if row[20] != 0 else 0
        longest_valid = max(longest_valid, run)
    report["Horizontal"] = {
        "FiniteDiagnostics": finite, "WaitingAssistAndBlendZero": disabled,
        "SameSequenceTimeBuildMatched": matched, "SupplementKeyCount": len(horizontal_keys),
        "MeasurementValidSamples": sum(row[20] != 0 for row in horizontal_values),
        "LongestValidLogRunSeconds": longest_valid / 50,
        "States": sorted({row[15] for row in horizontal_values}),
        "RejectReasons": sorted({row[23] for row in horizontal_values}),
        "MaximumIntegralMps2": max((math.hypot(row[10],row[11]) for row in horizontal_values), default=None),
    }
    report["Passed"] = report["Passed"] and finite and disabled and matched >= len(horizontal_keys) - 2
    report["Passed"] = report["Passed"] and all(
        len(base_keys & keys) >= len(keys) - 2 for keys in packet_keys.values())
report["BenchChecksPassed"] = report["Passed"] and (not args.reset or boot_captured) and (
    not args.stationary_bench or report["StationaryBenchHealth"]["Passed"]) and timing["AllObservedTasksWithinBudget"]
report_folder = root / "build" / "reports"
report_folder.mkdir(parents=True, exist_ok=True)
(report_folder / f"{args.record_stem}_usb_startup.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
deployment_file = report_folder / f"{deployment_stem}_{args.device}_deployment.json"
if deployment_file.is_file() and not args.input_file:
    deployment = json.loads(deployment_file.read_text(encoding="utf-8"))
    deployment["usb_startup"] = report
    deployment["usb_log_integrity_verified"] = report["Passed"]
    deployment["usb_startup_verified"] = report["Passed"] and boot_captured
    deployment["bench_checks_verified"] = report["BenchChecksPassed"]
    if args.stationary_bench:
        deployment["stationary_bench_verified"] = report["StationaryBenchHealth"]["Passed"]
    deployment_file.write_text(json.dumps(deployment, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("USB_LOG_INTEGRITY_PASSED" if report["Passed"] else "USB_LOG_INTEGRITY_FAILED", flush=True)
if not report["Passed"]:
    raise RuntimeError("IMU USB log integrity verification failed; see saved record.")
