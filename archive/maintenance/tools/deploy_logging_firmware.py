"""Back up, flash, and verify the logging build on an identified ESP32-S3."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

from serial.tools import list_ports

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser()
parser.add_argument("--device", choices=("aircraft", "receiver"), required=True)
parser.add_argument("--usb-only", action="store_true")
parser.add_argument("--port", required=True)
parser.add_argument("--expected-mac", required=True)
parser.add_argument("--firmware-sha256", required=True)
parser.add_argument("--model-sha256", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[3]
name = {"aircraft": "StampFly_PIDBlock_FlightTest400", "receiver": "M5Stamp_IMU_Rx"}[args.device]
known_mac = {"aircraft": "70:AF:09:DF:A6:C4", "receiver": "10:51:DB:55:A1:60"}[args.device]
if args.expected_mac.upper() != known_mac:
    raise RuntimeError("The specified device is not the configured lab device.")
if args.device == "aircraft" and not args.usb_only:
    raise RuntimeError("USB-only readiness must be supplied for the aircraft.")
firmware = root / "build/logging400" / f"{name}.bin"
model = root / f"{name}.slx"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if sha256(firmware) != args.firmware_sha256.lower():
    raise RuntimeError("Built firmware changed before flashing.")
if sha256(model) != args.model_sha256.lower():
    raise RuntimeError("Saved model changed before flashing.")
build = json.loads((root / "docs/history/logging_build.json").read_text(encoding="utf-8"))
if not (build["BuildPassed"] and build["Aircraft"] == "StampFly_PIDBlock_FlightTest400"
        and build["Receiver"] == "M5Stamp_IMU_Rx" and build["ControlHz"] == 400
        and build["PWMRequestedHz"] == 150000 and build["PWMBits"] == 8):
    raise RuntimeError("Both firmware builds must have passed.")
if firmware.stat().st_size > 0x140000:
    raise RuntimeError("Firmware does not fit the established app partition.")
device = [p for p in list_ports.comports() if p.device == args.port
          and (p.serial_number or "").upper() == known_mac]
if len(device) != 1:
    raise RuntimeError("Serial port does not match the identified device.")
tag = datetime.now().strftime("%Y%m%d_%H%M%S")
backup = root / "backups" / f"{name}_{args.port}_before_logging_{tag}_app0.bin"
backup.parent.mkdir(exist_ok=True)
runner = root / "tools/run_esptool.py"
prefix = "logging_" + args.device


def run(label, *arguments):
    subprocess.run([sys.executable, str(runner), label, "--chip", "esp32s3",
                    "--port", args.port, "--baud", "460800", *arguments], check=True)


if args.device == "aircraft":
    # Verify the already saved successful-flight image against flash. This
    # preserves an exact rollback without a long, redundant partition read.
    prior_report=root / "docs/history/logging_aircraft_deployment.json"
    if not prior_report.is_file():
        prior_report=root / "docs/history/pid_flight_deployment.json"
    old = json.loads(prior_report.read_text(encoding="utf-8"))
    rollback = root / old["firmware"]
    if sha256(rollback) != old["firmware_sha256"]:
        raise RuntimeError("Previous successful-flight rollback image changed.")
    run(prefix + "_rollback_verify", "--after", "no_reset", "verify_flash",
        "0x10000", str(rollback))
    shutil.copy2(rollback, backup)
else:
    run(prefix + "_backup", "--after", "no_reset", "read_flash", "0x10000", "0x140000", str(backup))
    if backup.stat().st_size != 0x140000:
        raise RuntimeError("Incomplete backup; refusing to flash.")
run(prefix + "_flash", "--before", "no_reset", "--after", "no_reset",
    "write_flash", "0x10000", str(firmware))
run(prefix + "_verify", "--before", "no_reset", "--after", "hard_reset",
    "verify_flash", "0x10000", str(firmware))
destination = root / "firmware/logging400"
destination.mkdir(parents=True, exist_ok=True)
for suffix in (".bin", ".bootloader.bin", ".partitions.bin"):
    source = firmware.parent / (name + suffix)
    if source.is_file():
        shutil.copy2(source, destination / source.name)
report = {
    "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
    "device": args.device, "port_at_flash": args.port, "mac": known_mac,
    "model": model.name, "model_sha256": sha256(model),
    "firmware": str((destination / firmware.name).relative_to(root)).replace("\\", "/"),
    "firmware_sha256": sha256(firmware), "firmware_bytes": firmware.stat().st_size,
    "app_offset": "0x10000", "app_backup": str(backup.relative_to(root)).replace("\\", "/"),
    "flash_verified": True, "verification_result": "digest matched",
    "usb_only_confirmed_by_user": args.usb_only, "flight_commands_sent": False,
    "firmware_revision": 1502 if args.device=="aircraft" else 1501, "flash_log": f"logs/{prefix}_flash.log",
    "verify_log": f"logs/{prefix}_verify.log",
}
(root / f"docs/logging_{args.device}_deployment.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"LOGGING_{args.device.upper()}_FLASHED_AND_VERIFIED", flush=True)
