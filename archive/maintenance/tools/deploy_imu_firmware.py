"""Back up and deploy the validated IMU Filter image on the lab StampFly."""
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
parser.add_argument("--usb-only", action="store_true", required=True)
parser.add_argument("--port", default="COM4")
parser.add_argument("--firmware-sha256", required=True)
parser.add_argument("--model-sha256", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[3]
model = root / "StampFly_IMU400.slx"
firmware = root / "firmware/history/imu400/StampFly_IMU400.bin"
known_mac = "70:AF:09:DF:A6:C4"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if sha256(model) != args.model_sha256.lower():
    raise RuntimeError("Saved IMU model changed before deployment.")
if sha256(firmware) != args.firmware_sha256.lower():
    raise RuntimeError("Validated IMU firmware changed before deployment.")
for filename in ("imu_flight_verification.json", "imu_control_verification.json"):
    if not json.loads((root / "docs" / "history" / filename).read_text(encoding="utf-8"))["Passed"]:
        raise RuntimeError("Both offline verifications must pass.")
build = json.loads((root / "docs/history/imu_flight_build.json").read_text(encoding="utf-8"))
if not (build["BuildPassed"] and build["BuildAction"] == "Build"
        and build["Step"] == .0025 and build["PWMHz"] == 150000
        and build["PWMBits"] == 8 and build["PIDCount"] == 7
        and build["FirmwareRevision"] == 1701):
    raise RuntimeError("IMU build does not match the validated flight settings.")
if firmware.stat().st_size > 0x140000:
    raise RuntimeError("IMU firmware exceeds the established application partition.")
devices = [p for p in list_ports.comports() if p.device == args.port
           and (p.serial_number or "").upper() == known_mac]
if len(devices) != 1:
    raise RuntimeError("Selected port is not the identified lab aircraft.")
runner = root / "tools/run_esptool.py"
tag = datetime.now().strftime("%Y%m%d_%H%M%S")
backup = root / "backups" / f"StampFly_{args.port}_before_imu400_{tag}.bin"
backup.parent.mkdir(exist_ok=True)
previous = json.loads((root / "docs/history/basic_aircraft_deployment.json").read_text(encoding="utf-8"))
rollback = root / previous["firmware"]
if sha256(rollback) != previous["firmware_sha256"]:
    raise RuntimeError("The successful-flight rollback image changed.")


def run(label, *arguments):
    subprocess.run([sys.executable, str(runner), label, "--chip", "esp32s3",
                    "--port", args.port, "--baud", "460800", *arguments], check=True)


# Establish an exact rollback by comparing the current app with its saved BIN.
run("imu400_rollback_verify", "--after", "no_reset", "verify_flash", "0x10000", str(rollback))
shutil.copy2(rollback, backup)
run("imu400_flash", "--before", "no_reset", "--after", "no_reset",
    "write_flash", "0x10000", str(firmware))
run("imu400_verify", "--before", "no_reset", "--after", "hard_reset",
    "verify_flash", "0x10000", str(firmware))
report = {
    "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
    "device": "aircraft", "port_at_flash": args.port, "mac": known_mac,
    "model": model.name, "model_sha256": sha256(model),
    "firmware": "firmware/history/imu400/StampFly_IMU400.bin", "firmware_sha256": sha256(firmware),
    "firmware_bytes": firmware.stat().st_size, "build_id": 1401, "firmware_revision": 1701,
    "control_hz": 400, "pwm_requested_hz": 150000, "pwm_bits": 8, "radio_channel": 3,
    "motor_output_enabled": True, "corrected_angular_velocity_to_pid": True,
    "app_offset": "0x10000", "written_regions": ["application"],
    "app_backup": backup.relative_to(root).as_posix(),
    "rollback_firmware": previous["firmware"], "rollback_sha256": sha256(rollback),
    "rollback_verified_before_flash": True, "flash_verified": True, "flash_completed": True,
    "verification_result": "digest matched", "usb_only_confirmed_by_user": args.usb_only,
    "physical_flight_tested": False, "flight_commands_sent": False,
    "flash_log": "logs/imu400_flash.log", "verify_log": "logs/imu400_verify.log",
}
(root / "docs/history/imu_aircraft_deployment.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("IMU400_FLASHED_AND_VERIFIED", flush=True)
