"""Deploy the dedicated-PID comparison to the known USB-only StampFly."""
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
parser.add_argument("--expected-mac", required=True)
parser.add_argument("--firmware-sha256", required=True)
parser.add_argument("--model-sha256", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[3]
name = "StampFly_PIDBlock_FlightTest400"
model = root / f"{name}.slx"
firmware = root / "build/pid_flight400" / f"{name}.bin"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if sha256(firmware) != args.firmware_sha256.lower():
    raise RuntimeError("Built firmware hash changed; refusing to flash.")
if sha256(model) != args.model_sha256.lower():
    raise RuntimeError("Saved model changed after build; refusing to flash.")
build = json.loads((root / "docs/history/pid_flight_build.json").read_text(encoding="utf-8"))
verification = json.loads((root / "docs/history/pid_flight_verification.json").read_text(encoding="utf-8"))
if not (build["BuildPassed"] and build["Model"] == name and build["PIDCount"] == 7
        and build["Step"] == 0.0025 and build["PWMHz"] == 150000 and build["PWMBits"] == 8
        and verification["Passed"] and verification["Samples"] == 12000):
    raise RuntimeError("Build or dedicated-PID model checks are incomplete.")
devices = [p for p in list_ports.comports()
           if p.device == args.port and (p.serial_number or "").upper() == args.expected_mac.upper()]
if len(devices) != 1:
    raise RuntimeError("Selected port does not match the expected StampFly.")
tag = datetime.now().strftime("%Y%m%d_%H%M%S")
backup = root / "backups" / f"StampFly_{args.port}_before_pid_test_{tag}_app0.bin"
backup.parent.mkdir(exist_ok=True)
report = {
    "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
    "device": {"port_at_flash": args.port, "mac": args.expected_mac.upper()},
    "model": model.name, "model_sha256": sha256(model),
    "baseline_model": "archive/aircraft/StampFly_Official_FlightTest400.slx",
    "firmware": f"firmware/pid_experiment/{name}.bin",
    "firmware_sha256": sha256(firmware), "app_offset": "0x10000",
    "app_backup": str(backup.relative_to(root)).replace("\\", "/"),
    "motor_output_enabled": True, "usb_only_confirmed_by_user": True,
    "dedicated_pid_count": 7, "strict_equivalence_expected": False,
    "baseline_firmware": "firmware/history/current/StampFly_Official_FlightTest400.bin",
    "baseline_firmware_sha256": sha256(root / "firmware/history/current/StampFly_Official_FlightTest400.bin"),
    "logger_port_untouched": "COM9", "physical_flight_verified": False,
    "flash_verified": False,
}
runner = root / "tools/run_esptool.py"


def run(label, *arguments):
    subprocess.run([sys.executable, str(runner), label, "--chip", "esp32s3", "--port", args.port,
                    "--baud", "460800", *arguments], check=True)


run("pid_flight_app_backup", "--after", "no_reset", "read_flash", "0x10000", "0x140000", str(backup))
if backup.stat().st_size != 0x140000:
    raise RuntimeError("Incomplete app backup; refusing to flash.")
run("pid_flight_flash", "--before", "no_reset", "--after", "no_reset", "write_flash", "0x10000", str(firmware))
run("pid_flight_verify", "--before", "no_reset", "--after", "hard_reset", "verify_flash", "0x10000", str(firmware))
destination = root / "firmware/pid_experiment"
destination.mkdir(parents=True, exist_ok=True)
for suffix in (".bin", ".bootloader.bin", ".partitions.bin"):
    source = firmware.parent / (name + suffix)
    if source.is_file():
        shutil.copy2(source, destination / source.name)
report.update({"flash_verified": True, "verification_result": "digest matched",
               "flash_log": "logs/pid_flight_flash.log", "verify_log": "logs/pid_flight_verify.log"})
(root / "docs/history/pid_flight_deployment.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("PID_FLIGHT_FIRMWARE_FLASHED_AND_VERIFIED", flush=True)
