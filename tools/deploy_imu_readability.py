"""Deploy the verified reorganized IMU400, preserving the flown IMU image."""
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
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
known_mac = "70:AF:09:DF:A6:C4"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_report(name):
    return json.loads((root / "docs" / name).read_text(encoding="utf-8"))


model = root / "StampFly_IMU400.slx"
build = read_report("imu_readability_build.json")
verification = read_report("imu_readability_verification.json")
previous = read_report("imu_aircraft_deployment.json")
firmware = Path(build["FirmwareFile"])
rollback = root / previous["firmware"]
expected = (build["BuildPassed"] and build["BuildAction"] == "Build"
            and build["Step"] == .0025 and build["PWMHz"] == 150000
            and build["PWMBits"] == 8 and build["PIDCount"] == 7
            and build["FirmwareRevision"] == 1701 and build["RadioChannel"] == 3
            and verification["Passed"] and verification["Logging"]["Passed"])
if not expected:
    raise RuntimeError("The reorganized IMU flight validation has not passed.")
if not (digest(model) == build["ModelSHA256"] == verification["ModelSHA256"]):
    raise RuntimeError("Saved model changed after validation or build.")
if digest(firmware) != build["FirmwareSHA256"]:
    raise RuntimeError("Built firmware changed after validation.")
if firmware.stat().st_size > 0x140000:
    raise RuntimeError("Firmware exceeds the established application partition.")
if digest(rollback) != previous["firmware_sha256"]:
    raise RuntimeError("The previously flown IMU rollback image changed.")
devices = [p for p in list_ports.comports() if p.device == args.port
           and (p.serial_number or "").upper() == known_mac]
if len(devices) != 1:
    raise RuntimeError("Selected port does not identify the lab aircraft.")

runner = root / "tools/run_esptool.py"
tag = datetime.now().strftime("%Y%m%d_%H%M%S")
backup = root / "backups" / f"StampFly_{args.port}_before_imu_readability_{tag}.bin"
backup.parent.mkdir(exist_ok=True)


def run(label, *arguments):
    subprocess.run([sys.executable, str(runner), label, "--chip", "esp32s3",
                    "--port", args.port, "--baud", "460800", *arguments], check=True)


# Verify the exact currently installed application before retaining it for rollback.
run("imu_readability_rollback_verify", "--after", "no_reset",
    "verify_flash", "0x10000", str(rollback))
shutil.copy2(rollback, backup)
destination = root / "firmware/imu400_readability"
destination.mkdir(exist_ok=True)
for file in build["BuildFiles"]:
    source = Path(file)
    shutil.copy2(source, destination / source.name)
distributed = destination / firmware.name
assert digest(distributed) == build["FirmwareSHA256"]
run("imu_readability_flash", "--before", "no_reset", "--after", "no_reset",
    "write_flash", "0x10000", str(distributed))
run("imu_readability_verify", "--before", "no_reset", "--after", "hard_reset",
    "verify_flash", "0x10000", str(distributed))
report = {
    "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
    "device": "aircraft", "port_at_flash": args.port, "mac": known_mac,
    "model": model.name, "model_sha256": digest(model),
    "firmware": distributed.relative_to(root).as_posix(), "firmware_sha256": digest(distributed),
    "firmware_bytes": distributed.stat().st_size, "build_id": 1401, "firmware_revision": 1701,
    "control_hz": 400, "pwm_requested_hz": 150000, "pwm_bits": 8, "radio_channel": 3,
    "motor_output_enabled": True, "corrected_angular_velocity_to_pid": True,
    "app_offset": "0x10000", "written_regions": ["application"],
    "app_backup": backup.relative_to(root).as_posix(),
    "rollback_firmware": previous["firmware"], "rollback_sha256": digest(rollback),
    "rollback_verified_before_flash": True, "flash_verified": True, "flash_completed": True,
    "verification_result": "digest matched", "usb_only_confirmed_by_user": args.usb_only,
    "physical_flight_tested": False, "flight_commands_sent": False,
    "flash_log": "logs/imu_readability_flash.log", "verify_log": "logs/imu_readability_verify.log",
    "verification_record": "docs/imu_readability_verification.json",
    "build_record": "docs/imu_readability_build.json",
    "previous_deployment_record": "docs/imu_aircraft_deployment.json",
}
(root / "docs/imu_readability_aircraft_deployment.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("IMU400_READABILITY_FLASHED_AND_VERIFIED", flush=True)
